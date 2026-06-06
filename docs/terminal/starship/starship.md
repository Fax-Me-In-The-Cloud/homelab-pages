# Starship

[Starship](https://starship.rs/) is a fast, cross-shell prompt written in Rust. It shows contextual information (git branch, k8s context, exit codes) without slowing down the shell.

## Installation

```bash
brew install starship
```

Then add the init hook to your shell config. For `zsh`, add to `~/.zshrc`:

```bash
eval "$(starship init zsh)"
```

## Configuration

Starship reads from `~/.config/starship.toml`. Download the current config:

```bash
curl -o ~/.config/starship.toml https://raw.githubusercontent.com/spaelling/homelab-pages/main/docs/terminal/starship/starship.toml
```

Or copy it from this repo — the file is embedded below:

```toml title="starship.toml"
--8<-- "terminal/starship/starship.toml"
```
