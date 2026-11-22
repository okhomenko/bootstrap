# Bootstrap changes

- Keep shared machine and user setup here. Put personal Git identity and global co-author hook settings in `config`, and Chargebee Git settings in `config-cbee`.
- After changing these repositories, commit and push the changes, then run `bootstrap update` to pull and apply all configured repositories. Do not apply changes with a direct `mise bootstrap` command during normal updates.
- On first setup, save `private_bootstrap_repo` and `chargebee_bootstrap_repo` with `mise vars NAME=<URL>` or answer the `--prompt-vars` prompts. Confirm saved values with `mise vars NAME`; `bootstrap update` uses them on later runs.
