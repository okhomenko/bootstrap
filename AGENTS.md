# Bootstrap changes

- Keep shared machine and user setup in this repository. Put personal Git identity and global co-author hook settings in the private `config` repository.
- After changing either repository, commit and push the changes, then run `bootstrap update` to pull and apply both repositories. Do not apply these changes with a direct `mise bootstrap` command during normal updates.
- On first setup, save `private_bootstrap_repo` with `mise vars private_bootstrap_repo=<URL>` or answer the `--prompt-vars` prompt. Confirm the saved value with `mise vars private_bootstrap_repo`; `bootstrap update` uses it on later runs.
