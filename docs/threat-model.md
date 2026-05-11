# Threat Model

## Assets to protect

- API keys, cloud credentials, SSH keys, OAuth tokens.
- Private project source code and customer data.
- WSL distro rollback exports.
- User shell configuration and package manager state.

## Main risks

```text
secret leak
  -> script prints credential contents

destructive migration
  -> old distro unregistered before backup validation

bad update
  -> package/runtime update breaks active projects

LLM overreach
  -> agent runs broad fixes without evidence or approval
```

## Mitigations

- Secret-looking files are reported by metadata only.
- Update scripts default to preview.
- WSL unregister is not automated.
- Doctor checks provide before/after evidence.
- Scripts avoid hard-coded private paths or tokens.
