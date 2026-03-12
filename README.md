<p align="center">
  <img src="https://img.shields.io/badge/Zsh%20Plugin-diskguard-blue?style=plastic">
  <img src="https://img.shields.io/badge/zsh%20version-%E2%89%A55.0-blue?style=plastic">
  <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20BSD-lightgrey?style=plastic">
  <img src="https://img.shields.io/badge/license-MIT-green?style=plastic">
  <img src="https://img.shields.io/github/stars/TomfromBerlin/diskguard?style=plastic">
  <img src="https://img.shields.io/github/downloads/TomfromBerlin/diskguard/total?style=plastic&labelColor=grey&color=blue">
  </p>
  
_Memo to self: They'll clone this repository again and again and not leave a single comment. Yes, not even a tiny star. But at least my code is traveling around the world._

# Zsh DiskGuard Plugin

🛡️ Intelligent disk space monitoring for write operations in Zsh

<details><summary> 🚀 Quick Start</summary>

```zsh
 # Install
 git clone https://github.com/TomfromBerlin/diskguard ~/.config/zsh/plugins/diskguard
 echo "source ~/.config/zsh/plugins/zsh-disk-guard/diskguard.plugin.zsh" >> ~/.zshrc
 source ~/.zshrc
```
This will only run the plugin temporarily. For permanent installation (also with the plugin manager or framework of your choice), see the 🛠️ Install section.
</details>

## ✨ Features

- ⚡ **Smart Performance**: Staged checking based on data size
- 🪂 **Predictive**: Checks if there's enough space *before* writing
- 🔧 **Configurable**: Adjust thresholds and behavior
- 🫥 **Very Low Overhead**: Minimal checks for small files
- 📦 **Plugin Manager Ready**: Works with oh-my-zsh, zinit, antigen, etc.
- 👣 **Progress bar**: Percentage and visual progress
- 💾 **Display of useful information**: total size of data to be processed, required and available storage space on the destination disk, file name and size of the file just processed
- ⏱️ **Display of the total time** required for the file operation(s)

## 🖥️ Usage

Since this is a plugin, manual execution is neither necessary nor useful. The plugin reacts to certain triggers and executes the corresponding actions automatically. Simply use `cp`, `mv`, and `rsync` as usual, e.g., `cp <source> <dest>`. No additional options should be specified. The plugin in action can be seen in the following clip. The plugin's status can be checked via the command line. See the 🎛️ Control section for more information.

<details><summary> ← Click here to see two output examples with low disk space warning</summary>

```zsh

# Automatically checked
cp large-file.iso /backup/
# ⚠️  Warning: Partition /backup is 85% full!
# Continue anyway? [y/N]

# Prevents write if not enough space
mv bigdata/ /mnt/small-disk/
# ❌ ERROR: Not enough disk space on /mnt/small-disk!
#    Required: 5 GiB
#    Available: 3 GiB
#    Missing: 2048 MiB

# Smart: skips remote targets
rsync -av files/ user@remote:/backup/  # No local check

```
</details>
<!--
[Zsh Disk Guard feat. a progress bar.webm](https://github.com/user-attachments/assets/2ae905e8-cadd-49eb-b5e1-1d3a0a6e21e9)
-->

| 👁️‍🗨️ Note |
|:-|
| The plugin uses its own aliases for the **`cp`** and **`mv`** commands, so if you use this plugin and **`cp`** _and/or_ **`mv`** in other scripts, you should consider prefixing the commands in those scripts with `command`, e.g., `command cp <source> <dest>`. Existing aliases are ignored because the plugin calls these programs with the `command` prefix. That said, if you rely on your existing aliases, you should not consider using this plugin.
The functionality of the **`rsync`** program is barely affected. The plugin only checks whether the target is local or remote and whether **`rsync`** was called with options. If the target is remote or unclear, or if options are detected, all checks are skipped. If **`rsync`** is called without options and the destination is local but there is not enough disk space, a warning will be issued and a request will be made as to whether the file operation should be performed anyway. Apart from that, **`rsync`** is always called only with the user-specific options (if any), since it has its own output (e.g. its own progress bar). |

## ❔ Why This Plugin?

- ✅ With: Predictive warnings, safe operations, peace of mind
- ❌ Without: Disk full errors mid-copy, wasted time, corrupted files


## 📝 Requirements

<details><summary>**Zsh 5.0+** (released 2012)</summary>
The version is checked when the plugin is loaded. If the version is too low, the plugin will not load. To manually check, run the following command at the command line:
   
  ```zsh
  echo $ZSH_VERSION
  ```
  
Upgrade: See [zsh.org](https://www.zsh.org/)
 </details>
 
<details><summary>Standard Unix tools</summary>

- df: Checks and displays the free disk space. Only mounted partitions are checked.
- stat: Used here to determine the file system status instead of the file status.
- du: Checks and displays the used disk space.
- cp: to copy files from one place to another
- mv: rename SOURCE to DEST, or move SOURCE(s) to DIRECTORY

</details>

## 🛠️ Install
<details><summary> ← click here</summary>

Add to your `.zshrc`:

### ZSH Unplugged (my recommendation)

```zsh
# (Do not use the following 15 lines along with other plugin managers!)
# <------------------------------------------------------------------------------------>
# ZSH UNPLUGGED start
#
# where do you want to store your plugins?
ZPLUGINDIR=$HOME/.config/zsh/plugins
#
# get zsh_unplugged and store it with your other plugins and source it
if [[ ! -d $ZPLUGINDIR/zsh_unplugged ]]; then
  git clone --quiet https://github.com/mattmc3/zsh_unplugged $ZPLUGINDIR/zsh_unplugged
fi
source $ZPLUGINDIR/zsh_unplugged/zsh_unplugged.zsh
#
# extend fpath and load zsh-defer
fpath+=($ZPLUGINDIR/zsh-defer)
autoload -Uz zsh-defer
#
# make list of the Zsh plugins you use (Consider paying attention to the loading order)
repos=(
  # ... your other plugins ...
  TomfromBerlin/diskguard
)
```

Insert the following code block before `autoload -Uz promptinit && promptinit`

```
# this block after all completion definitions (the zstyle ':completion [...] stuff)
if [[ -f "${ZPLUGINDIR}/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ]] ; then
    source "${ZPLUGINDIR}/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
# read documentation of zsh-autocomplete
else
    # tweak compinit
    alias compinit='compinit-tweak'
    compinit-tweak() {
    grep -q "ZPLUGINDIR/*/*" <<< "${@}" && \compinit "${@}"
    }
    # now load plugins
    autoload -Uz compinit && compinit -C -d ${zdumpfile}
fi
# now load plugins
plugin-load $repos
# ZSH UNPLUGGED end
# <------------------------------------------------------------------------------------>
```

💡 Best practice: place the second code block right before your prompt definitions and - as already mentioned - mandatory before `autoload -Uz promptinit && promptinit`.


Other pluginmanagers and frameworks:

### Antigen

add to your .zshrc:

```zsh
antigen bundle TomfromBerlin/diskguard
```

### Oh-My-Zsh

Enter the following command on the command line and confirm with Return

```zsh
git clone https://github.com/TomfromBerlin/diskguard ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/diskguard
```

then add to your .zshrc:

```zsh
plugins=(... diskguard)
```

### Zinit

add to your .zshrc:

```zsh
zinit light TomfromBerlin/diskguard
```

You can load the plugin with any other pluginmanagers as well.

⚠️ **Regardless which pluginmanager you use, the plugin may interfere with other plugins that monitor disk operations or use the wrapped commands (*cp*, *mv*, *rsync*). ⚠️**

### manual call via the command line

```zsh
git clone https://github.com/TomfromBerlin/diskguard ~/.config/zsh/plugins/diskguard
source ~/.config/zsh/plugins/zsh-disk-guard/diskguard.plugin.zsh
```

</details>

## 🧹 Uninstall

<details><summary> ← click here</summary>

Simply remove from your plugin list and restart Zsh.

### Temporary Disable

```zsh

zshdg disable

```

### To completely remove:

```zsh

zshdd unload
rm -rf ~/.config/zsh/plugins/diskguard

```

</details>

## 🪄 How It Works

### 📋 Two-Stage Checking

The plugin performs a quick or deep disk check depending on the data size before write operations.

- #### Quick Check (files <100 MiB):

  - Uses stat only (fast)
  - Warns if disk >80% full
  - No size calculation

- #### Deep Check (≥100 MiB or directories):

  - Calculates actual size with du
  - Verifies available space
  - Prevents failed operations

- #### Smart Skipping
  
  - Automatically skips checks for:
    - Remote targets (rsync user@host:/path)
    - Options ending with - (rsync -av files -n)
    - Unclear syntax

### Performance

|Scenario|Overhead|Check Type|
|-|-|-|
| cp small.txt /tmp | ~1ms | Usage only |
| cp file.iso /backup (5 GiB) | ~3ms | Full check |
| cp -r directory/ /tmp| Variable | Full check with du |

## ⚙️ Configure

This plugin should be ready to use right out of the box and requires no further configuration. However, you can adjust some settings to suit your needs.

<details><summary> ← click here for more</summary>

```zsh
# Set these settings before loading the plugin.
# To do this, either find the relevant settings in the script's configuration section
# and change only the values ​​(do not export them within the script), or enter one or
# more of the following commands in the command line (and then export them):

# set disk usage warning threshold to 90% (default value: 80%)
export DISKGUARD_THRESHOLD=90

# set scan threshold for deep check to 500 MiB (default value: 100 MiB)
export DISKGUARD_SCAN_THRESHOLD=$((500 * 1024 * 1024))

# Enable debug output (default value: 0)
export DISKGUARD_DEBUG=0

# disable plugin (default value: 1)
export DISKGUARD_ENABLED=1

# ──────────────────────────────────────────────────────────────────
# Do not play around with the following settings! I'm serious!

# commands to be wrapped, separated by spaces (default: "cp mv rsync")
export DISKGUARD_COMMANDS="cp mv rsync"

# However, if you want to change the default (not recommended!),
# further customization is required, i.e. you need to create suitable wrappers.
# See the diskguard_cp() function to see how this can be done.
# ──────────────────────────────────────────────────────────────────
```
</details>

# 🎛️ Control

```zsh
zshdg status    # Shows current configuration
```

```zsh
zshdg disable   # Temporarily disable
```

```zsh
zshdg enable    # Re-enable
```

```zsh
zshdg color    # switch between color mode and B/W mode
```

```zsh
zshdg default    # load default values
```

```zsh
zshdg threshold N    # set warn threshold in percent (N must be a number between 1 and 99)
```

```zsh
zshdg scan-theshold N    # set scan threshold in MB (N must be a number > 1)
```
# 💬 Contribute
Issues and PRs welcome at github.com/TomfromBerlin/zsh-disk-guard

License: MIT

Author: Tom (from Berlin)
