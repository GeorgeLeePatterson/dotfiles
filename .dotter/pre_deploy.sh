#!/bin/bash

# Backup existing files
backup_dir=~/.dotfile_bk

{{#each dotter.files}}
{{#if (command_success "test -f {{this}}")}}
mkdir -p $backup_dir/{{@key}}
mv -hf "{{this}}" ~/.dotfile_bk/{{@key}} || echo "Could not move {{@key}}" && exit 1
{{/if}}
{{/each}}
