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

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- Flag to track if deprecation warning has been shown
--- @type boolean
local deprecation_warning_shown = false

--- @type string|nil The GitHub repository name (e.g., "owner/repo")
local github_repository = nil

--- @type string The base URL for GitHub (defaults to "https://github.com")
local github_base_url = "https://github.com"

--- @type table<string, boolean> Set of reference IDs from the document
local references_ids_set = {}

--- Check if a string is empty or nil
--- @param s string|nil The string to check
--- @return boolean true if the string is nil or empty
local function is_empty(s)
  return s == nil or s == ''
end

--- Escape special pattern characters in a string
--- @param s string The string to escape
--- @return string The escaped string
local function escape_pattern(s)
  local escaped = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  return escaped
end

--- Create a GitHub URI link element
--- @param text string|nil The link text
--- @param uri string|nil The URI to link to
--- @return pandoc.Link|nil A Pandoc Link element or nil if text or uri is empty
local function github_uri(text, uri)
  if not is_empty(uri) and not is_empty(text) then
    return pandoc.Link({pandoc.Str(text --[[@as string]])}, uri --[[@as string]])
  end
  return nil
end

--- Extract metadata value from document meta, supporting both new nested structure and deprecated top-level keys
--- @param meta table The document metadata table
--- @param key string The metadata key to retrieve
--- @return string|nil The metadata value as a string, or nil if not found
local function get_metadata_value(meta, key)
  -- Check for the new nested structure first: extensions.github.key
  if meta['extensions'] and meta['extensions']['github'] and meta['extensions']['github'][key] then
    return pandoc.utils.stringify(meta['extensions']['github'][key])
  end

  -- Check for deprecated top-level key and warn
  if meta[key] then
    if not deprecation_warning_shown then
      quarto.log.warning(
        "Using '" .. key .. "' directly in metadata is deprecated. " ..
        "Please use the following structure instead:\n" ..
        "extensions:\n" ..
        "  github:\n" ..
        "    " .. key .. ": value"
      )
      deprecation_warning_shown = true
    end
    return pandoc.utils.stringify(meta[key])
  end

  return nil
end

--- Get repository name from metadata or git remote
--- This function extracts the GitHub repository name either from document metadata
--- or by querying the git remote origin URL
--- @param meta table The document metadata table
--- @return table The metadata table (unchanged)
function get_repository(meta)
  local meta_github_base_url = get_metadata_value(meta, 'base-url')
  local meta_github_repository = get_metadata_value(meta, 'repository-name')

  --- Set base URL if provided, otherwise use default
  if not is_empty(meta_github_base_url) then
    github_base_url = meta_github_base_url --[[@as string]]
  end

  if is_empty(meta_github_repository) then
    local is_windows = package.config:sub(1, 1) == "\\"
    if is_windows then
      remote_repository_command = "(git remote get-url origin) -replace '.*[:/](.+?)(\\.git)?$', '$1'"
    else
      remote_repository_command =
      "git remote get-url origin 2>/dev/null | sed -E 's|.*[:/]([^/]+/[^/.]+)(\\.git)?$|\\1|'"
    end

    local handle = io.popen(remote_repository_command)

    if handle then
      local git_repo = handle:read("*a"):gsub("%s+$", "")
      handle:close()
      if not is_empty(git_repo) then
        meta_github_repository = git_repo
      end
    end
  end

  github_repository = meta_github_repository
  return meta
end

--- Extract and store reference IDs from the document
--- This function collects all reference IDs from the document to distinguish
--- between actual citations and GitHub mentions
--- @param doc pandoc.Pandoc The Pandoc document
--- @return pandoc.Pandoc The document (unchanged)
function get_references(doc)
  local references = pandoc.utils.references(doc)

  for _, reference in ipairs(references) do
    if reference.id then
      references_ids_set[reference.id] = true
    end
  end
  return doc
end

--- Process GitHub mentions in citations
--- Distinguishes between actual bibliography citations and GitHub @mentions
--- @param cite pandoc.Cite The citation element
--- @return pandoc.Cite|pandoc.Link The original citation or a GitHub mention link
function mentions(cite)
  if references_ids_set[cite.citations[1].id] then
    return cite
  else
    local mention_text = pandoc.utils.stringify(cite.content)
    local github_link = github_uri(mention_text, github_base_url .. "/" .. mention_text:sub(2))
    return github_link or cite
  end
end

--- Process GitHub issues, pull requests, and discussions
--- Converts various GitHub reference formats into clickable links
--- Supported formats:
--- - #123 (issue in current repo)
--- - owner/repo#123 (issue in specific repo)
--- - GH-123 (issue in current repo)
--- - https://example.com/owner/repo/issues/123 (full URL)
--- @param elem pandoc.Str The string element to process
--- @return pandoc.Link|nil A GitHub link or nil if no valid pattern found
function issues(elem)
  local user_repo = nil
  local issue_number = nil
  local type = nil
  local short_link = nil

  if elem.text:match("^#(%d+)$") then
    issue_number = elem.text:match("^#(%d+)$")
    user_repo = github_repository
    type = "issues"
    short_link = "#" .. issue_number
  elseif elem.text:match("^([^/]+/[^/#]+)#(%d+)$") then
    user_repo, issue_number = elem.text:match("^([^/]+/[^/#]+)#(%d+)$")
    type = "issues"
    short_link = user_repo .. "#" .. issue_number
  elseif elem.text:match("^GH%-(%d+)$") then
    issue_number = elem.text:match("^GH%-(%d+)$")
    user_repo = github_repository
    type = "issues"
    short_link = "#" .. issue_number
  else
    -- Dynamic pattern matching for base URL
    local escaped_base_url = escape_pattern(github_base_url)
    local url_pattern = "^" .. escaped_base_url .. "/([^/]+/[^/]+)/([^/]+)/(%d+)$"
    if elem.text:match(url_pattern) then
      user_repo, type, issue_number = elem.text:match(url_pattern)
      if user_repo == github_repository then
        short_link = "#" .. issue_number
      else
        short_link = user_repo .. "#" .. issue_number
      end
    end
  end

  local uri = nil
  local text = nil
  if not is_empty(short_link) and not is_empty(issue_number) and not is_empty(user_repo) and not is_empty(type) then
    if type == "issues" or type == "discussions" or type == "pull" then
      uri = github_base_url .. "/" .. user_repo .. '/' .. type .. '/' .. issue_number
      text = pandoc.utils.stringify(short_link)
    end
  end

  return github_uri(text, uri)
end

--- Process GitHub commit references
--- Converts various commit reference formats into clickable links
--- Supported formats:
--- - 40-character SHA (commit in current repo)
--- - owner/repo@sha (commit in specific repo)
--- - username@40-character-sha (commit by user)
--- - https://example.com/owner/repo/commit/sha (full URL)
--- @param elem pandoc.Str The string element to process
--- @return pandoc.Link|nil A GitHub commit link or nil if no valid pattern found
function commits(elem)
  local user_repo = nil
  local commit_sha = nil
  local type = nil
  local short_link = nil

  if elem.text:match("^(%w+)$") and elem.text:len() == 40 then
    commit_sha = elem.text:match("^(%w+)$")
    user_repo = github_repository
    type = "commit"
    short_link = commit_sha:sub(1, 7)
  elseif elem.text:match("^([^/]+/[^/@]+)@(%w+)$") then
    user_repo, commit_sha = elem.text:match("^([^/]+/[^/@]+)@(%w+)$")
    type = "commit"
    short_link = user_repo .. "@" .. commit_sha:sub(1, 7)
  elseif elem.text:match("^(%w+)@(%w+)$") then
    user_repo, commit_sha = elem.text:match("^(%w+)@(%w+)$")
    if commit_sha:len() == 40 then
      type = "commit"
      short_link = user_repo .. "@" .. commit_sha:sub(1, 7)
    end
  else
    -- Dynamic pattern matching for base URL
    local escaped_base_url = escape_pattern(github_base_url)
    local url_pattern = "^" .. escaped_base_url .. "/([^/]+/[^/]+)/([^/]+)/(%w+)$"
    if elem.text:match(url_pattern) then
      user_repo, type, commit_sha = elem.text:match(url_pattern)
      if user_repo == github_repository then
        short_link = commit_sha:sub(1, 7)
      else
        short_link = user_repo .. "@" .. commit_sha:sub(1, 7)
      end
    end
  end

  local uri = nil
  local text = nil
  if not is_empty(short_link) and not is_empty(commit_sha) and not is_empty(user_repo) and not is_empty(type) then
    if type == "commit" and commit_sha and commit_sha:len() == 40 then
      uri = github_base_url .. "/" .. user_repo .. '/' .. type .. '/' .. commit_sha
      text = pandoc.utils.stringify(short_link)
    end
  end

  return github_uri(text, uri)
end

--- Main GitHub processing function
--- Attempts to convert string elements into GitHub links by trying different patterns
--- @param elem pandoc.Str The string element to process
--- @return pandoc.Str|pandoc.Link The original element or a GitHub link
function github(elem)
  local link = nil
  if link == nil then
    link = issues(elem)
  end

  if link == nil then
    link = commits(elem)
  end

  if link == nil then
    return elem
  else
    return link
  end
end

--- Pandoc filter configuration
--- Defines the order of filter execution:
--- 1. Extract references from the document
--- 2. Get repository information from metadata
--- 3. Process string elements for GitHub patterns
--- 4. Process citations for GitHub mentions
return {
  { Pandoc = get_references },
  { Meta = get_repository },
  { Str = github },
  { Cite = mentions }
}
