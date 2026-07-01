# Setup Improvements Kanban — MangoWM + Quickshell

Data: 2026-06-28

## Modelos / Dev Team

- Tentativa de usar workers/subagentes: **bloqueada** porque o provider `openrouter` está sem API key neste ambiente.
- Fallback usado: Dev Team em contexto, com evidência local via terminal/files.
- Lentes usadas: Lead Engineer, Debugger, Product Engineer, Reviewer/SRE.

## Done

- [x] Backup reversível antes das mudanças
  - `~/dotfiles-backups/meloworld-improvements-20260628-193810`
- [x] Restaurado autostart de ambiente Mango/session
  - `dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP`
  - `systemctl --user start mango-session.target`
- [x] Adicionado fallback ABNT2 no autostart
  - `setxkbmap -layout br -variant abnt2 -model pc105 -option caps:escape`
- [x] Escondidos 17 atalhos `.desktop` mortos do Waydroid com `NoDisplay=true`
  - não foram deletados; reversível pelo backup
- [x] Criado verificador reutilizável
  - `scripts/verify-meloworld-setup.sh`
- [x] Validação executada
  - Mango parse: PASS
  - Quickshell config ativo: PASS
  - Launcher focus: PASS
  - Kitty config: PASS
  - Launcher IPC open/close: PASS
  - Logs críticos Quickshell: PASS
  - Waydroid entries hidden: PASS

## Next / Backlog

- [ ] Reduzir warning falso do `WorkspaceBar.qml` sobre Hyprland em sessão Mango
  - risco: médio se remover compatibilidade Hyprland; fazer com patch pequeno ou flag backend
- [ ] Criar quick-ref de keybinds e rollback
  - arquivo sugerido: `docs/MANGO-KEYBINDS-QUICKREF.md`
- [ ] Consolidar divergências entre live tree e `~/meloworld-dotfiles-mangowm`
  - risco: médio; fazer diff-only antes
- [ ] Limpar warnings de ícones sem imagem no launcher
  - agora os Waydroid principais foram escondidos; reavaliar logs depois de reiniciar/abrir launcher
- [ ] Avaliar `.face` ausente no dashboard
  - opção segura: symlink/cópia de avatar escolhido pelo usuário

## Verificação

Comando:

```bash
~/.config/meloworld-dotfiles/scripts/verify-meloworld-setup.sh
```

Último resultado: **PASS**.

## Rollback

Restaurar backup:

```bash
rsync -a --delete ~/dotfiles-backups/meloworld-improvements-20260628-193810/meloworld-dotfiles/ ~/.config/meloworld-dotfiles/
cp -a ~/dotfiles-backups/meloworld-improvements-20260628-193810/local-share-applications/waydroid.*.desktop ~/.local/share/applications/
mmsg dispatch reload_config
```
