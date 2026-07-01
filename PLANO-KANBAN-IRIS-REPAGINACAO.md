# Kanban — Repaginação Meloworld + Iris

## Objetivo
Estabilizar o Meloworld após a sessão do Antigravity, concluir a integração do Iris e iniciar melhorias leves de interface sem quebrar o desktop vivo.

## Backlog
- [ ] Repaginação visual mais ampla de launcher/dashboard após estabilização.
- [ ] Templates Iris adicionais para Zed/Ghostty/GTK/libadwaita avançado.

## Fazendo
- [ ] Corrigir erros runtime do Quickshell (`requestActivate`, `selectedIndex undefined`).
- [ ] Corrigir integração Iris → Kitty/GTK com fallback e arquivo gerado não vazio.
- [ ] Fazer botão Dark Mode forçar `iris --dark 1` mesmo com wallpapers claros.

## Verificação
- [ ] Backup antes de alterações.
- [ ] Verificar QML com `qmllint`/execução curta do Quickshell quando ambiente permitir.
- [ ] Verificar `iris --json-only` e arquivos gerados em `~/.cache/meloworld/`.
- [ ] Verificar `kitty.conf` sem duplicata óbvia e include seguro.
- [ ] Validar parse Mango com `mango -c ~/.config/mango/config.conf -p`.

## Feito
- [x] Diagnóstico inicial da sessão do Antigravity.
- [x] Identificados erros principais: `AppLauncher.qml` e Kitty include vazio/duplicado.
- [x] Backup completo criado antes das correções.
- [x] Dock removida da UI principal e do painel/dashboard; módulos antigos mantidos como legado reversível por enquanto.
