"""Bilans et codes de sortie : commandes internes et fixtures isolées seulement."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / 'scripts/bilan.sh'
HEADER = '── Bilan de l’opération'


class BilanTests(unittest.TestCase):
    def run_bilan(self, body, title='05 · Test', args=()):
        # Ne source aucun fichier personnel et n'appelle aucun gestionnaire réel.
        with tempfile.TemporaryDirectory(prefix='cachyos-bilan-') as temp:
            env = dict(os.environ, HOME=temp, NO_COLOR='1')
            env.pop('BASH_ENV', None)
            return subprocess.run(
                ['/bin/bash', '-c',
                 'set -euo pipefail; source "$1"; shift; '
                 'title=$1; shift; bilan_init "$title" "$@"; ' + body,
                 'fixture', str(LIBRARY), title, *args],
                env=env, text=True, capture_output=True)

    def test_success_lists_confirmed_and_unchanged_separately(self):
        result = self.run_bilan('bilan_debut; bilan_action "paquet A installé"; '
                                'bilan_ignore "paquet B déjà présent"; '
                                'bilan_note "tester l’application"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Résultat     : Réussi', result.stderr)
        for message in ('paquet A installé', 'paquet B déjà présent', 'tester l’application'):
            self.assertIn(message, result.stderr)
        self.assertEqual(result.stderr.count(HEADER), 1)
        self.assertEqual(result.stdout, '')

    def test_early_failure_keeps_code_and_does_not_claim_changes(self):
        result = self.run_bilan('bilan_erreur "prérequis absent"; exit 7')
        self.assertEqual(result.returncode, 7)
        self.assertIn('Résultat     : Échoué', result.stderr)
        self.assertIn('prérequis absent', result.stderr)
        self.assertIn('aucune modification confirmée', result.stderr)
        self.assertNotIn('Partiellement réussi', result.stderr)

    def test_failed_attempt_does_not_invent_a_success(self):
        result = self.run_bilan('bilan_debut; false')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Résultat     : Échoué', result.stderr)
        self.assertIn('des changements peuvent subsister', result.stderr)

    def test_partial_failure_keeps_completed_actions(self):
        result = self.run_bilan('bilan_debut; bilan_action "première action terminée"; '
                                'bilan_erreur "deuxième action échouée"; exit 9')
        self.assertEqual(result.returncode, 9)
        self.assertIn('Partiellement réussi', result.stderr)
        self.assertIn('première action terminée', result.stderr)

    def test_cancellation_is_distinct_even_when_script_returns_nonzero(self):
        for code in (0, 1):
            with self.subTest(code=code):
                result = self.run_bilan(f'bilan_annule "refus utilisateur"; exit {code}')
                self.assertEqual(result.returncode, code)
                self.assertIn('Résultat     : Annulé', result.stderr)
                self.assertNotIn('Résultat     : Réussi', result.stderr)

    def test_cancellation_after_work_keeps_the_completed_work(self):
        result = self.run_bilan('bilan_debut; bilan_action "paquets installés"; '
                                'bilan_annule "configuration refusée"')
        self.assertIn('Annulé après le début des opérations', result.stderr)
        self.assertIn('paquets installés', result.stderr)

    def test_interruption_keeps_signal_status_and_completed_work(self):
        result = self.run_bilan('bilan_debut; bilan_action "étape terminée"; kill -TERM "$$"')
        self.assertEqual(result.returncode, 143)
        self.assertIn('Résultat     : Interrompu', result.stderr)
        self.assertIn('étape terminée', result.stderr)
        self.assertEqual(result.stderr.count(HEADER), 1)

    def test_default_simulations_are_recognized(self):
        for title, body in (('09 · Purge', 'APPLY=false'),
                            ('10 · Disques', 'MODE=preview'),
                            ('11 · AUR', 'MODE=--dry-run')):
            with self.subTest(title=title):
                result = self.run_bilan(body, title=title)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('Résultat     : Simulation terminée', result.stderr)

    def test_dry_run_does_not_pollute_rendered_stdout(self):
        result = self.run_bilan('printf "configuration candidate\\n"', args=('--dry-run',))
        self.assertEqual(result.stdout, 'configuration candidate\n')
        self.assertIn('Simulation terminée', result.stderr)

    def test_subshell_and_repeated_calls_do_not_duplicate_summary(self):
        result = self.run_bilan('value=$(bilan_print 0; printf valeur); '
                                '[[ "$value" == valeur ]]; bilan_print 0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr.count(HEADER), 1)

    def test_silent_success_stays_silent_but_failure_is_visible(self):
        result = self.run_bilan('SILENT_MODE=true')
        self.assertEqual(result.stderr, '')
        result = self.run_bilan('SILENT_MODE=true; exit 1')
        self.assertIn(HEADER, result.stderr)

    def test_cleanup_result_is_reported_after_rollback(self):
        result = self.run_bilan('cleanup() { local rc=$?; trap - EXIT; '
                                'bilan_note "retour arrière terminé"; '
                                'bilan_print "$rc"; exit "$rc"; }; '
                                'trap cleanup EXIT; bilan_debut; exit 8')
        self.assertEqual(result.returncode, 8)
        self.assertIn('retour arrière terminé', result.stderr)
        self.assertEqual(result.stderr.count(HEADER), 1)

    def test_rolled_back_actions_are_not_presented_as_partial_success(self):
        result = self.run_bilan('bilan_debut; bilan_action "règle ajoutée"; '
                                'BILAN_RETOUR_ARRIERE=true; '
                                'bilan_note "retour arrière effectué"; exit 1')
        self.assertIn('Résultat     : Échoué', result.stderr)
        self.assertIn('Actions terminées avant le retour arrière', result.stderr)
        self.assertNotIn('Partiellement réussi', result.stderr)

    def test_long_action_list_is_counted_and_condensed(self):
        result = self.run_bilan('for n in 1 2 3 4 5 6 7 8 9 10; do '
                                'bilan_action "action $n"; done')
        self.assertIn('Actions confirmées : 10', result.stderr)
        self.assertIn('2 autres éléments', result.stderr)
        self.assertNotIn('    - action 9', result.stderr)

    def test_help_and_lists_have_no_extra_summary(self):
        for args in (('--help',), ('--list',), ('--list-groups',)):
            with self.subTest(args=args):
                result = self.run_bilan('printf catalogue', args=args)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, 'catalogue')
                self.assertEqual(result.stderr, '')

    def test_all_eleven_scripts_report_argument_errors_once(self):
        # Deux arguments invalides arrêtent chaque script avant les contrôles
        # machine, les commandes d'installation et toute écriture système.
        with tempfile.TemporaryDirectory(prefix='cachyos-bilan-') as temp:
            env = dict(os.environ, HOME=temp, NO_COLOR='1')
            env.pop('BASH_ENV', None)
            for script in sorted(ROOT.glob('*.sh')):
                with self.subTest(script=script.name):
                    result = subprocess.run(
                        ['/bin/bash', str(script), '--option-inconnue', '--autre-option'],
                        env=env, text=True, capture_output=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stderr.count(HEADER), 1, result.stderr)
                    self.assertNotIn('Résultat     : Réussi', result.stderr)


if __name__ == '__main__':
    unittest.main()
