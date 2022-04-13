# ZSH

Personal interactive shell config for `zsh`.

## Install `ohmyzsh`

Follow [these](https://github.com/ohmyzsh/ohmyzsh#basic-installation) instructions to get `ohmyzsh` installed.

### Enable plugins

#### Pre-requisites

##### Autojump

For the `autojump` plugin to work, you need to install [`autojump`](https://github.com/wting/autojump) first:
```shell
brew update
brew install autojump
```

##### Pyenv

For the `pyenv` plugin to work, you need to install [`pyenv`](https://github.com/pyenv/pyenv) first:
```shell
brew update
brew install pyenv
```

#### Specify the plugins to enable

Replace the `plugins` value in the `~/.zshrc` with:
```shell
plugins=(git nvm npm yarn autojump pyenv)
```

This will enable the following plugins:
- [git](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git)
- [nvm](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/nvm)
- [npm](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/npm)
- [yarn](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/yarn)
- [autojump](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/autojump)
- [pyenv] (https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/pyenv)
