# Recovery

## WSL migration recovery checklist

```text
1. Stop and preserve current state.
2. Confirm available exports/backups.
3. Validate backup tar readability when possible.
4. Use `wsl -l -v` to identify exact distro names.
5. Do not unregister any distro until replacement is validated.
6. Restore/import from backup only after choosing a target install path.
```

## Package update recovery checklist

```text
1. Capture doctor output.
2. Check `/var/log/apt/history.log` and `/var/log/apt/term.log`.
3. Check held/broken packages with `dpkg --audit`.
4. Avoid random purge/reinstall loops.
5. Prefer one small fix, then rerun doctor.
```
