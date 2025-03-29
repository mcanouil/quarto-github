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

local github_repository = nil
local references_ids_set = {}

local function is_empty(s)
  return s == nil or s == ''
end

local function github_uri(text, uri)
  if not is_empty(uri) and not is_empty(text) then
    return pandoc.Link(text, uri)
  end
end

function get_repository(meta)
  local meta_github_repository = nil
  if is_empty(meta['repository-name']) then
    local is_windows = package.config:sub(1, 1) == "\\"
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
        meta_github_repository = git_repo
      end
    end
  else
    meta_github_repository = pandoc.utils.stringify(meta['repository-name'])
  end

  github_repository = meta_github_repository
  return meta
end

function get_references(doc)
  local references = pandoc.utils.references(doc)
  
  for _, reference in ipairs(references) do
    if reference.id then
      references_ids_set[reference.id] = true
    end
  end
  return doc
end

function mentions(cite)
  if references_ids_set[cite.citations[1].id] then
    return cite
  else
    return github_uri(cite.content, "https://github.com/" .. cite.content[1].text:sub(2))
  end
end

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
  elseif elem.text:match("^https://github.com/([^/]+/[^/]+)/([^/]+)/(%d+)$") then
    user_repo, type, issue_number = elem.text:match("^https://github.com/([^/]+/[^/]+)/([^/]+)/(%d+)$")
    if user_repo == github_repository then
      short_link = "#" .. issue_number
    else
      short_link = user_repo .. "#" .. issue_number
    end
  end

  local uri = nil
  local text = nil
  if not is_empty(short_link) and not is_empty(issue_number) and not is_empty(user_repo) and not is_empty(type) then
    if type == "issues" or type == "discussions" or type == "pull" then
      uri = "https://github.com/" .. user_repo .. '/' .. type .. '/' .. issue_number
      text = pandoc.utils.stringify(short_link)
    end
  end

  return github_uri(text, uri)
end

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
  elseif elem.text:match("^https://github.com/([^/]+/[^/]+)/([^/]+)/(%w+)$") then
    user_repo, type, commit_sha = elem.text:match("^https://github.com/([^/]+/[^/]+)/([^/]+)/(%w+)$")
    if user_repo == github_repository then
      short_link = commit_sha:sub(1, 7)
    else
      short_link = user_repo .. "@" .. commit_sha:sub(1, 7)
    end
  end

  local uri = nil
  local text = nil
  if not is_empty(short_link) and not is_empty(commit_sha) and not is_empty(user_repo) and not is_empty(type) then
    if type == "commit" and commit_sha:len() == 40 then
      uri = "https://github.com/" .. user_repo .. '/' .. type .. '/' .. commit_sha
      text = pandoc.utils.stringify(short_link)
    end
  end

  return github_uri(text, uri)
end

function github(elem)
  local link = nil
  if is_empty(link) then
    link = issues(elem)
  end

  if is_empty(link) then
    link = commits(elem)
  end

  if is_empty(link) then
    return elem
  else
    return link
  end
end

return {
  {Pandoc = get_references},
  {Meta = get_repository},
  {Str = github},
  {Cite = mentions}
}
