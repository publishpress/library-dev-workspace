# Set default values for PLUGIN_NAME and PLUGIN_TYPE if not set
export PLUGIN_NAME=${PLUGIN_NAME:-"UNDEFINED"}
export PLUGIN_TYPE=${PLUGIN_TYPE:-"UNDEFINED"}

export LANG='en_US.UTF-8'
export LANGUAGE='en_US:en'
export LC_ALL='en_US.UTF-8'
[ -z "xterm-256color" ] && export TERM=xterm

# If you come from bash you might have to change your $PATH.
export PATH=/project/node_modules/.bin:/project/vendor/bin:/project/lib/vendor/bin:/scripts:/scripts/deprecated-scripts:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="ys"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git gh asdf wp-cli docker)

source $ZSH/oh-my-zsh.sh

# User configuration

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PROJECT_PATH="/project"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias zshconfig="mate ~/.zshrc"
alias ohmyzsh="mate ~/.oh-my-zsh"
alias wp="wp --allow-root"
alias proj="cd $PROJECT_PATH"
alias ppbuild="pbuild"
alias c="composer"

# If GH auth file exists, login to gh command
if [[ -f $PROJECT_PATH/dev-workspace/cache/gh-token.txt ]]; then
     GH_TOKEN=$(cat $PROJECT_PATH/dev-workspace-cache/gh-token.txt)
     gh auth login --with-token <<< $GH_TOKEN
fi

# Set the prompt color based on PLUGIN_TYPE
if [[ "$PLUGIN_TYPE" == "PRO" ]]; then
    COLOR="%{$bg[yellow]%}"
elif [[ "$PLUGIN_TYPE" == "FREE" ]]; then
    COLOR="%{$bg[cyan]%}"
fi

export PROMPT="
%{$bg[magenta]%}%{$fg[white]%} 🐧 Dev-workspace v${DEV_WORKSPACE_VERSION} %{$reset_color%} $COLOR%{$fg[black]%} $PLUGIN_NAME $PLUGIN_TYPE %{$reset_color%}
%{$terminfo[bold]$fg[blue]%}#%{$reset_color%} %(#,%{$bg[yellow]%}%{$fg[black]%}%n%{$reset_color%},%{$fg[cyan]%}%n) %{$reset_color%}@ %{$fg[green]%}%m %{$reset_color%}in %{$terminfo[bold]$fg[yellow]%}%~%{$reset_color%}${hg_info}${git_info}${svn_info}${venv_info} [%*] $exit_code
%{$terminfo[bold]$fg[magenta]%}➜ %{$reset_color%}"

if [[ -f /project/.zshrc ]]; then
    source /project/.zshrc
    echo "Loaded local zshrc from /project/.zshrc"
fi
