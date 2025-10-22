--[[
# MIT License
#
# Copyright (c) 2025 Mickaël Canouil
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- MC Git - Git repository utilities for Quarto Lua filters and shortcodes
--- @module git
--- @author Mickaël Canouil
--- @version 1.0.0

local git_module = {}

-- ============================================================================
-- GIT REPOSITORY UTILITIES
-- ============================================================================

--- Check if a string is empty or nil
--- @param s string|nil The string to check
--- @return boolean true if the string is nil or empty
local function is_empty(s)
  return s == nil or s == ''
end

--- Get repository name from git remote origin URL
--- Executes shell command to extract repository name from git remote
--- @return string|nil The repository name (e.g., "owner/repo") or nil if not found
--- @usage local repo = git_module.get_repository()
function git_module.get_repository()
  local is_windows = package.config:sub(1, 1) == "\\"
  local remote_repository_command

  if is_windows then
    remote_repository_command = "(git remote get-url origin) -replace '.*[:/](.+?)(\\.git)?$', '$1'"
  else
    remote_repository_command = "git remote get-url origin 2>/dev/null | sed -E 's|.*[:/]([^/]+/[^/.]+)(\\.git)?$|\\1|'"
  end

  local handle = io.popen(remote_repository_command)
  if handle then
    local git_repo = handle:read("*a"):gsub("%s+$", "")
    handle:close()
    if not is_empty(git_repo) then
      return git_repo
    end
  end

  return nil
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return git_module
