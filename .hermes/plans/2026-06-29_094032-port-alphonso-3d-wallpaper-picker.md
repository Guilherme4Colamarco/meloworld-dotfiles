# Port Alphonso 3D Wallpaper Picker Implementation Plan

> **For Hermes:** usar este plano como kanban. Implementar task-by-task, com backup antes de mexer em config viva e verificação ad-hoc em `/tmp/hermes-verify-*` no final.

**Goal:** portar o wallpaper picker 3D do Alphonso para o setup MangoWM/Quickshell atual do meloworld, mantendo paths PT-BR, wallpapers de vídeo, Iris dynamic theming e `SUPER+W` abrindo o picker certo.

**Architecture:** usar o picker 3D standalone como componente principal em `quickshell/wallpaper/WallpaperPicker.qml`, acionado por `WallpaperState` + IPC `target wallpaper`. Não reintroduzir o wallpaper picker dentro do launcher como caminho principal; launcher pode manter `openWallpaper()` como fallback, mas o bind do usuário deve abrir o picker 3D fullscreen/overlay.

**Tech Stack:** Quickshell/QML, MangoWM config, `awww`, `mpvpaper`, `ffmpeg`, `magick`, `jq`, Iris, GTK/Kitty generated colors.

---

## Contexto atual

### Fonte Alphonso/local encontrada

Provável base Alphonso/antiga:

- `/home/geko/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml`

Picker vivo atual:

- `/home/geko/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml`

O picker atual já parece derivado do 3D:

- usa `angleStep`;
- usa `slotX(offset)` com `Math.sin(...)`;
- usa `slotScale(offset)` com `Math.cos(...)`;
- usa `Rotation { axis.y: 1; angle: ... }`;
- tem `smoothSelected` com animação;
- é `PanelWindow` standalone com `WallpaperState.visible`.

Diferenças importantes já presentes no setup atual e que devem ser preservadas:

- paths PT-BR: `~/Imagens/Wallpapers` e `~/Vídeos/Wallpapers`;
- formatos de vídeo expandidos: `mp4/mkv/webm/mov/avi/flv/wmv/ts/m4v/ogv`;
- `IrisColors.loadWallpaperText(...)` após aplicar wallpaper;
- cache em `~/.cache/meloworld/wallpaper-thumbs`;
- bind atual planejado: `SUPER+w -> qs ipc call wallpaper toggle`.

---

## Kanban

### DONE

- [x] K0 — Descoberta inicial: localizar picker Alphonso/antigo e comparar com picker vivo.

### TODO

- [ ] K1 — Backup reversível da config viva.
- [ ] K2 — Consolidar core do picker 3D standalone.
- [ ] K3 — Integrar IPC + bind `SUPER+W`.
- [ ] K4 — Ajustar UX/foco/navegação.
- [ ] K5 — Validar com verificação ad-hoc e screenshot.
- [ ] K6 — Sincronizar espelho `~/meloworld-dotfiles-mangowm`.

---

## Task K1: Backup reversível

**Objective:** criar snapshot antes de mexer no picker e nos binds.

**Files:**

- Backup source: `/home/geko/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml`
- Backup source: `/home/geko/.config/meloworld-dotfiles/quickshell/theme/WallpaperState.qml`
- Backup source: `/home/geko/.config/meloworld-dotfiles/quickshell/shell.qml`
- Backup source: `/home/geko/.config/meloworld-dotfiles/mango/config.conf`
- Backup target: `/home/geko/dotfiles-backups/alphonso-3d-picker-port-YYYYMMDD-HHMMSS/`

**Steps:**

1. Criar diretório de backup timestampado.
2. Copiar os quatro arquivos vivos para o backup preservando subpastas.
3. Registrar no output o caminho do backup.
4. Não alterar nada antes desse backup existir.

**Commands:**

```bash
stamp=$(date +%Y%m%d-%H%M%S)
backup="$HOME/dotfiles-backups/alphonso-3d-picker-port-$stamp"
mkdir -p "$backup/quickshell/wallpaper" "$backup/quickshell/theme" "$backup/quickshell" "$backup/mango"
cp -a "$HOME/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml" "$backup/quickshell/wallpaper/"
cp -a "$HOME/.config/meloworld-dotfiles/quickshell/theme/WallpaperState.qml" "$backup/quickshell/theme/"
cp -a "$HOME/.config/meloworld-dotfiles/quickshell/shell.qml" "$backup/quickshell/"
cp -a "$HOME/.config/meloworld-dotfiles/mango/config.conf" "$backup/mango/"
printf 'backup=%s\n' "$backup"
```

**Verification:**

```bash
test -s "$backup/quickshell/wallpaper/WallpaperPicker.qml"
test -s "$backup/quickshell/shell.qml"
test -s "$backup/mango/config.conf"
```

---

## Task K2: Consolidar core do picker 3D

**Objective:** deixar `WallpaperPicker.qml` como picker 3D standalone oficial, preservando melhorias do setup atual.

**Files:**

- Modify: `/home/geko/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml`

**Implementation checklist:**

1. Manter `PanelWindow` standalone, não embutir no launcher.
2. Manter:
   - `visible: WallpaperState.visible`;
   - `WlrLayershell.layer: WlrLayer.Overlay`;
   - `WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None`;
   - `focusDelay` chamando `keyInput.forceActiveFocus()`.
3. Preservar/ajustar geometria 3D:
   - `property real angleStep: 38`;
   - `slotX(offset)` com seno;
   - `slotAngle(offset)`;
   - `slotScale(offset)`;
   - `Rotation { axis { x: 0; y: 1; z: 0 } }`.
4. Preservar paths atuais:
   - `~/Pictures/Wallpapers`;
   - `~/Imagens/Wallpapers`;
   - `~/Vídeos/Wallpapers`.
5. Preservar formats atuais de vídeo:
   - `mp4 mkv webm mov avi flv wmv ts m4v ogv`.
6. Preservar aplicação de wallpapers:
   - imagem/gif via `awww`;
   - vídeo via `mpvpaper`;
   - lockscreen em `~/.config/quickshell/lockscreen/wallpaper.png`;
   - state em `~/.cache/meloworld/last-wallpaper` com `image:`/`video:`.
7. Preservar trigger do Iris:
   - `IrisColors.loadWallpaperText((wall.isVideo ? "video:" : "image:") + path)`.

**Pitfalls:**

- Não voltar para `~/Videos/Wallpapers` como diretório principal; ele é só compat symlink.
- Não remover `IrisColors.loadWallpaperText`, senão tema fica atrasado/stale.
- Evitar comandos shell com paths sem escape se for mexer no script; nomes com espaço existem.
- Não deixar o picker depender do launcher para abrir.

---

## Task K3: IPC + bind do Mango

**Objective:** garantir que `SUPER+W` abre o picker 3D standalone.

**Files:**

- Modify/check: `/home/geko/.config/meloworld-dotfiles/quickshell/shell.qml`
- Modify/check: `/home/geko/.config/meloworld-dotfiles/mango/config.conf`
- Check: `/home/geko/.config/meloworld-dotfiles/quickshell/theme/WallpaperState.qml`

**Expected state:**

`quickshell/shell.qml` deve ter:

```qml
IpcHandler {
    target: "wallpaper"
    function toggle(): void { WallpaperState.toggle() }
    function open(): void { WallpaperState.show() }
    function close(): void { WallpaperState.hide() }
}
```

`mango/config.conf` deve ter:

```conf
bind = SUPER,w,spawn,qs ipc call wallpaper toggle
```

E não deve ter o bind antigo como principal:

```conf
bind = SUPER,w,spawn,qs ipc call launcher openWallpaper
```

**Verification:**

```bash
qs ipc show | grep -A4 '^target wallpaper'
grep -nF 'bind = SUPER,w,spawn,qs ipc call wallpaper toggle' ~/.config/mango/config.conf
mango -c ~/.config/mango/config.conf -p
```

---

## Task K4: UX, foco e navegação

**Objective:** deixar o picker confortável no teclado e no visual.

**Files:**

- Modify: `/home/geko/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml`

**Acceptance criteria:**

- `SUPER+W` abre o picker fullscreen/overlay.
- Fundo escurece por cima da tela atual.
- Cards aparecem em carrossel 3D.
- `h`/seta esquerda move para anterior.
- `l`/seta direita move para próximo.
- `/` entra em busca.
- `Esc` limpa busca ou fecha picker.
- `Enter` aplica wallpaper selecionado.
- `r` escolhe aleatório.
- O card atual mostra preview animado quando gif/vídeo, sem travar tudo.
- Se thumbnails ainda não existem, o picker abre mesmo assim e vai preenchendo cache depois.

**Implementation notes:**

- Se o picker abre mas não recebe teclas, revisar `WlrKeyboardFocus.Exclusive` e `focusDelay`.
- Se a tela fica vazia, revisar `wallListProc` e cache `walls.json`.
- Se vídeo trava, manter preview em thumbnail para laterais e vídeo só no card central.

---

## Task K5: Verificação ad-hoc

**Objective:** provar que o port carregou e funciona sem chamar isso de suite oficial.

**Files:**

- Create temporary: `/tmp/hermes-verify-*.py`
- Remove temporary after run.

**Checks do script:**

1. `WallpaperPicker.qml` existe e contém marcadores 3D:
   - `angleStep`;
   - `slotX`;
   - `slotScale`;
   - `Rotation`;
   - `axis { x: 0; y: 1; z: 0 }`.
2. Paths PT-BR existem no QML:
   - `Pictures/Wallpapers`;
   - `Imagens/Wallpapers`;
   - `Vídeos/Wallpapers`.
3. Formatos de vídeo expandidos existem no find.
4. `IrisColors.loadWallpaperText` existe no apply path.
5. `shell.qml` tem `target: "wallpaper"`.
6. `mango/config.conf` tem bind `SUPER+w` para `wallpaper toggle`.
7. `mango -c ~/.config/mango/config.conf -p` passa.
8. `qs ipc show` lista `target wallpaper`.
9. `qs ipc call wallpaper open` retorna 0.
10. Screenshot via `grim /tmp/...png` confirma visualmente que o picker abriu.
11. `qs ipc call wallpaper close` retorna 0.
12. `qs list --all` sem `FATAL`.

**Command pattern:**

```bash
python /tmp/hermes-verify-XXXX.py
rm -f /tmp/hermes-verify-XXXX.py
```

**Expected output:**

```text
AD-HOC VERIFY SUMMARY
checks=N failed=0
removed temp verifier: /tmp/hermes-verify-XXXX.py
```

---

## Task K6: Sincronizar espelho/repo

**Objective:** depois que o live setup passar, copiar alterações para o repo espelho do usuário.

**Files:**

- Live: `/home/geko/.config/meloworld-dotfiles/...`
- Mirror: `/home/geko/meloworld-dotfiles-mangowm/...`

**Likely files to sync:**

```text
quickshell/wallpaper/WallpaperPicker.qml
quickshell/theme/WallpaperState.qml
quickshell/shell.qml
mango/config.conf
```

**Command pattern:**

```bash
rsync -a ~/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml ~/meloworld-dotfiles-mangowm/quickshell/wallpaper/WallpaperPicker.qml
rsync -a ~/.config/meloworld-dotfiles/quickshell/theme/WallpaperState.qml ~/meloworld-dotfiles-mangowm/quickshell/theme/WallpaperState.qml
rsync -a ~/.config/meloworld-dotfiles/quickshell/shell.qml ~/meloworld-dotfiles-mangowm/quickshell/shell.qml
rsync -a ~/.config/meloworld-dotfiles/mango/config.conf ~/meloworld-dotfiles-mangowm/mango/config.conf
```

**Verification:**

```bash
diff -u ~/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml ~/meloworld-dotfiles-mangowm/quickshell/wallpaper/WallpaperPicker.qml
diff -u ~/.config/meloworld-dotfiles/quickshell/shell.qml ~/meloworld-dotfiles-mangowm/quickshell/shell.qml
diff -u ~/.config/meloworld-dotfiles/mango/config.conf ~/meloworld-dotfiles-mangowm/mango/config.conf
```

Expected: no output for synced files.

---

## Rollback

Se o picker quebrar a sessão ou não abrir:

```bash
backup=/home/geko/dotfiles-backups/alphonso-3d-picker-port-YYYYMMDD-HHMMSS
cp -a "$backup/quickshell/wallpaper/WallpaperPicker.qml" ~/.config/meloworld-dotfiles/quickshell/wallpaper/WallpaperPicker.qml
cp -a "$backup/quickshell/theme/WallpaperState.qml" ~/.config/meloworld-dotfiles/quickshell/theme/WallpaperState.qml
cp -a "$backup/quickshell/shell.qml" ~/.config/meloworld-dotfiles/quickshell/shell.qml
cp -a "$backup/mango/config.conf" ~/.config/meloworld-dotfiles/mango/config.conf
mango -c ~/.config/mango/config.conf -p
mmsg dispatch reload_config || true
qs kill || true
qs -p ~/.config/quickshell -d
```

Se Hermes não herdar `WAYLAND_DISPLAY`, usar o recipe de restart Quickshell via env do processo Mango descrito na skill `wayland-wm-dotfiles`.

---

## Open questions

1. O usuário quer manter também o picker de wallpapers dentro do launcher (`launcher openWallpaper`) ou remover da UX principal?
   - Recomendação: manter como fallback, mas `SUPER+W` abre standalone 3D.
2. O visual 3D deve ser carrossel grande fullscreen ou card menor estilo launcher?
   - Recomendação: fullscreen overlay para diferenciar claramente do launcher.
3. Deve mostrar vídeos tocando no card central ou só thumbnail estática?
   - Recomendação: vídeo/gif no card central apenas; thumbnails estáticas nas laterais para performance.

---

## Definition of Done

- `SUPER+W` abre o picker 3D standalone.
- Cards aparecem em perspectiva 3D.
- Teclado funciona: `h/l`, setas, `/`, `Esc`, `Enter`, `r`.
- Imagens, gifs e vídeos são listados dos diretórios corretos.
- Aplicar wallpaper atualiza `last-wallpaper`, lockscreen e Iris imediatamente.
- Quickshell não mostra `FATAL`.
- Mango parse passa.
- Verificação ad-hoc `/tmp/hermes-verify-*` passa com `failed=0`.
- Espelho `~/meloworld-dotfiles-mangowm` fica sincronizado após validação.
