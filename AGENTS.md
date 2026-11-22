# Bootstrap changes

- Keep shared machine and user setup here. Put personal Git identity and global co-author hook settings in `config`, and Chargebee Git settings in `config-cbee`.
- After changing these repositories, commit and push the changes, then run `bootstrap update` to pull and apply all configured repositories. Do not apply changes with a direct `mise bootstrap` command during normal updates.
- On first setup, save the ordered, comma-separated `config_repos` value with `mise vars config_repos=<URL1>,<URL2>` or answer the `--prompt-vars` prompt. Confirm with `mise vars config_repos`; `bootstrap update` uses it on later runs. Existing installations migrate their former named vars to this list on the next update.
