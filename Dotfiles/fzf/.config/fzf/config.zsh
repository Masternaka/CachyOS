# Chargé par le paquet Zsh avant l'intégration native FZF.
# Préserver une valeur personnelle, y compris une valeur explicitement vide.
if [[ -z ${FZF_DEFAULT_OPTS+x} ]]; then
    export FZF_DEFAULT_OPTS='--height=60% --layout=reverse --border=rounded --info=inline --color=bg:#1e1e2e,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,hl:#89b4fa,hl+:#cba6f7,pointer:#f5c2e7,marker:#a6e3a1,spinner:#f9e2af'
fi
# Aucune commande de recherche globale, écriture de cache ou requête réseau.
