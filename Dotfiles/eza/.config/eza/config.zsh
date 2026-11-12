# Chargé par le paquet Zsh ; les alias ll/la/lt restent dans aliases.zsh.
# Couleurs ANSI explicites, sans installer de thème supplémentaire.
if [[ -z ${EZA_COLORS+x} ]]; then
    export EZA_COLORS='di=1;34:ln=1;36:ex=1;32:or=1;31'
fi
