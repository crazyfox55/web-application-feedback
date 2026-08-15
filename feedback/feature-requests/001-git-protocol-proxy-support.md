# Git Protocol Support for External API Proxy

## Request
Add git smart HTTP protocol support to the EdubaWare External API Proxy so that standard git commands (clone, pull, push, fetch) work through the proxy.

## Current Limitation
The external API proxy currently only supports GitHub REST API endpoints (GET, POST, PUT, PATCH, DELETE for JSON resources). It does not support the git smart HTTP protocol, which means `git clone`, `git pull`, and `git push` commands fail with authentication errors.

## Use Case
Allow agents and users to interact with GitHub repositories using standard git commands instead of manually implementing file operations via the REST API.

Example workflow that should work:
```bash
git clone https://api.eduba.io/api/icm/external-api-proxy/github-key1/crazyfox55/EdubaWareVision.git
cd EdubaWareVision
# make changes
git push origin main
```

## Current Configuration

The External API Key is configured as:
- **Proxy Name**: `github-key1`
- **Target Base URL**: `https://api.github.com`
- **Auth Header**: `Authorization: Bearer <PAT>`
- **PAT Permissions**: Contents (read/write), Issues (read), Metadata (read), Pull requests (read/write)

This configuration **already has everything needed** for git operations - the PAT has the right permissions, and the proxy can inject the auth header. We just need to support the git protocol endpoints.

## Technical Requirements

### 1. Support Git Smart HTTP Protocol Endpoints

The proxy needs to handle these git-specific endpoints in addition to the REST API:

**Upload Pack (Clone/Fetch/Pull):**
- `GET /{owner}/{repo}.git/info/refs?service=git-upload-pack`
- `POST /{owner}/{repo}.git/git-upload-pack`

**Receive Pack (Push):**
- `GET /{owner}/{repo}.git/info/refs?service=git-receive-pack`
- `POST /{owner}/{repo}.git/git-receive-pack`

Note: These are GitHub's endpoints, not `/repos/` prefixed like the REST API.

### 2. Content-Type Handling

Git protocol uses specific content types:
- Request: `application/x-git-upload-pack-request` or `application/x-git-receive-pack-request`
- Response: `application/x-git-upload-pack-result` or `application/x-git-receive-pack-result`

### 3. Authentication Translation

The proxy should:
1. Accept the EdubaWare session token (as bearer token or in URL)
2. Translate it to the GitHub PAT associated with the external API key
3. Forward requests to GitHub with proper authentication
4. Handle authentication errors gracefully

### 4. URL Patterns to Support

```
# Current (REST API only)
{PROXY_URL}/github-key1/repos/{owner}/{repo}
{PROXY_URL}/github-key1/repos/{owner}/{repo}/contents/path

# New (Git Protocol) - note the different path structure
{PROXY_URL}/github-key1/{owner}/{repo}.git/info/refs?service=git-upload-pack
{PROXY_URL}/github-key1/{owner}/{repo}.git/git-upload-pack
{PROXY_URL}/github-key1/{owner}/{repo}.git/git-receive-pack
```

The git protocol uses `/{owner}/{repo}.git/` while REST API uses `/repos/{owner}/{repo}/`.

## Authentication Options That Work with Git

Any of these can be used behind the proxy:

1. **Personal Access Token (PAT)** - Recommended
   - Works over HTTPS
   - Can be scoped to specific permissions
   - Easy to rotate

2. **GitHub App Installation Token**
   - Short-lived
   - More secure
   - Requires token refresh logic

3. **OAuth Token**
   - Good for user-delegated access
   - Standard OAuth flow

4. **SSH Keys** (Alternative approach)
   - Could proxy SSH protocol instead
   - More complex to implement
   - Different URL pattern: `git@proxy:owner/repo.git`

## Implementation Approach

### Option A: Full Git Protocol Proxy (Required)
Proxy the git smart HTTP protocol by:
1. Detecting git protocol requests by content-type and endpoint pattern
2. Injecting GitHub PAT authentication server-side (keeping PAT secure)
3. Streaming binary pack data between client and GitHub
4. Preserving git protocol semantics

**Security requirement**: The PAT must never be exposed to the ICM sandbox. The proxy must inject authentication server-side, just like it does for REST API calls.

### Option B: REST API Fallback (Current Workaround)
Continue using REST API with custom scripts, but this requires:
- Manual file synchronization
- Custom conflict resolution
- No git history/blame/diff tools
- More complex agent logic

## Impact

**High Value:**
- Enables standard git workflows
- Reduces agent complexity
- Better developer experience
- Familiar tooling (git CLI, GUIs)

**Moderate Complexity:**
- Requires binary protocol proxying
- Must handle streaming/chunked responses
- Need robust error handling

## Workaround Until Implemented

Use GitHub REST API for file operations:
```bash
# Get file content
curl -H "Authorization: Bearer $TOKEN" \
  "$PROXY/github-key1/repos/owner/repo/contents/path/to/file"

# Update file
curl -X PUT -H "Authorization: Bearer $TOKEN" \
  -d '{"message":"commit msg","content":"base64","sha":"file-sha"}' \
  "$PROXY/github-key1/repos/owner/repo/contents/path/to/file"
```

## Related

- Git Smart HTTP Protocol: https://git-scm.com/docs/http-protocol
- GitHub API Authentication: https://docs.github.com/en/rest/authentication
- Git Credential Helpers: https://git-scm.com/docs/gitcredentials

## Submitted
2026-08-13
