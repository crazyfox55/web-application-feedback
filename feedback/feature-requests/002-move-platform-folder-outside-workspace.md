# Move .platform Folder Outside Workspace Tree

## Request
Move the `.platform/` folder from `workspace/icm/{sessionId}/.platform/` to `workspace/platform/{sessionId}/` so that agent and client code cannot access ICM internal metadata and configuration files.

## Current Limitation
The `.platform/` folder currently exists within the ICM workspace tree at `workspace/icm/{sessionId}/.platform/`, making it visible and accessible to:
- Agents running in the sandbox
- Client code in the workspace
- File tree listings
- Git operations

This folder contains ICM platform metadata:
- `baseline.json` - Repository baseline
- `session-config.json` - Session configuration
- `session.json` - Session details and configuration
- `workspace-manifest.json` - Workspace state

## Concerns

### Current Issues
1. **Unintended Visibility**: Agents can read internal ICM platform metadata
2. **Git Contamination**: The folder appears as untracked in `git status`, creating noise
3. **Information Disclosure**: Platform configuration and session details are visible to workspace code
4. **Template Detection**: Agents can discover which template created the session

## Proposed Solution

### New Directory Structure

**Current:**
```
workspace/
└── icm/
    └── {sessionId}/
        ├── .platform/          ← Accessible to agent
        │   ├── baseline.json
        │   ├── session-config.json
        │   ├── session.json
        │   └── workspace-manifest.json
        ├── README.md
        └── ... (workspace files)
```

**Proposed:**
```
workspace/
├── icm/
│   └── {sessionId}/
│       ├── README.md
│       └── ... (workspace files)  ← Agent only sees this
└── platform/
    └── {sessionId}/              ← Outside agent access
        ├── baseline.json
        ├── session-config.json
        ├── session.json
        └── workspace-manifest.json
```

## Implementation Details

### 1. Path Changes
- **Current path**: `/workspace/icm/{sessionId}/.platform/`
- **New path**: `/workspace/platform/{sessionId}/`

### 2. Sandbox Configuration
The sandbox container should:
- Mount `/workspace/icm/{sessionId}/` as the working directory (current behavior)
- **NOT** mount or expose `/workspace/platform/{sessionId}/`
- Keep platform files accessible only to the ICM host process

### 3. File System Permissions
Set directory permissions so:
- ICM host process: **Read/Write** to `/workspace/platform/{sessionId}/`
- Sandbox agent: **No access** (directory not visible)

### 4. Backward Compatibility
For existing sessions with `.platform/` in the old location:
- Migrate files to new location on first load
- Add `.platform/` to `.gitignore` if it doesn't exist in workspace
- Clean up old `.platform/` directory after migration

## Benefits

### Security
- ✅ **Zero access** to internal ICM metadata from sandbox
- ✅ **Prevents disclosure** of platform configuration details
- ✅ **Defense in depth** - platform metadata isolated from workspace code

### User Experience
- ✅ **Cleaner workspace** - no `.platform/` in file tree
- ✅ **Cleaner git status** - no untracked platform files
- ✅ **Less confusion** - users/agents don't see internal infrastructure

### Operational
- ✅ **Clear separation** between workspace content and platform metadata
- ✅ **Easier to reason about** what's accessible to agents
- ✅ **Supports future protected globs** feature without relying on it for security

## Alternative Considered: Protected Globs

The upcoming "Protected Globs" feature would hide `.platform/` from the file tree and prevent access. However:
- ❌ **Still in same directory tree** - technically accessible if protection fails
- ❌ **Relies on security through filtering** rather than isolation
- ❌ **More complex** - requires glob matching logic to enforce

**Moving the folder is simpler and more secure** - true isolation rather than filtered access.

## Context from Discussion

From Slack conversation on 2026-08-12:

**Don Roy discovered** that agents can access `.platform/` and read session metadata:
> "I was curious how it knows what template it was made from I just kept poking haha"

**crazyfox55 acknowledged the issue:**
> "I'll move those files outside of the folder structure so the agent doesn't have access"

**Discussion about Protected Globs:**
While Protected Globs can hide files from the tree and control exports, moving the folder **outside the workspace entirely** is a cleaner architectural solution that doesn't rely on glob filtering for security.

## Priority
**High** - This is a security and privacy improvement that reduces the attack surface and prevents unintended information disclosure.

## Submitted
2026-08-13
