# HAVEN default .bashrc, installed to every new user's home via /etc/skel.
# Source: Phase 3, Step 5 of FLAGSHIP-LINUX-DISTRO-BUILD-GUIDE.md.

# If not running interactively, don't do anything
case $- in
  *i*) ;;
    *) return;;
esac

# HAVEN default prompt: user@host:cwd (git branch) $
parse_git_branch() { git branch 2>/dev/null | sed -n 's/^\* //p'; }
PS1='\u@\h:\w $(parse_git_branch)\$ '
export PS1

# HAVEN aliases (Layer 4: Learning and Onboarding)
alias sec-update='sudo apt update && sudo apt full-upgrade -y && sudo freshclam'
# Full system + AV definition update in one command. Run weekly; the MOTD reminds you.

alias cis-scan='sudo oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis_level1_server --results /tmp/cis-results.xml /usr/share/xml/scap/ssg/content/ssg-debian12-ds.xml && echo "Report: /tmp/cis-results.xml"'
# Runs the CIS Level 1 server scan and tells you where the report landed.

alias lab-status='haven-healthcheck'
# Runs the health-check script; green means your lab environment is sane.

alias fw-show='sudo nft list ruleset 2>/dev/null || sudo iptables -L -n -v'
# Shows the active firewall ruleset regardless of backend.

alias ports-now='ss -tulpn'
# What is listening right now, with process names. The first command in any triage.

# Sane history for operators
export HISTSIZE=10000 HISTFILESIZE=20000 HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# Color support
if [ -x /usr/bin/dircolors ]; then
  eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
fi
