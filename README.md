[![Ceasefire Now](https://badge.techforpalestine.org/default)](https://techforpalestine.org/learn-more)

# My Dotfiles Bare Repo


I store my dotfiles in this repo. It is public so I could access it on new machines but feel free to explore or make a similar setup with my commands. I only added the lazygit alias over the [Arch wiki guide](https://wiki.archlinux.org/title/Dotfiles). Run the reset --mixed HEAD in case I need to override existing settings.


Setup a dotfile bare repo
```bash
git init --bare ~/.dotfiles
alias dotfiles='/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
alias dotfiles-lazygit='lazygit --work-tree=$HOME --git-dir=$HOME/.dotfiles'
dotfiles config status.showUntrackedFiles no
```

Your dotfiles can be replicated on a new system like:
```bash
git clone --bare <git-repo-url> $HOME/.dotfiles
alias dotfiles='/usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME"'
alias dotfiles-lazygit='lazygit --work-tree=$HOME --git-dir=$HOME/.dotfiles'
dotfiles config --local status.showUntrackedFiles no


dotfiles reset --mixed HEAD
dotfiles checkout
```

These are the folders I am racking. A bare repo can't check for new files, only for updates. So running this command will check for me.
```bash
dotfiles add ~/.config/hypr/
dotfiles add ~/.config/nvim/
dotfiles add ~/.config/fontconfig/
dotfiles add ~/.config/kanata/
dotfiles add ~/.config/cspell/
dotfiles add ~/.config/ghosttly/
```
