local _, ns = ...
local A = ns.A

-- Planning is prepared after login, not by the Leveling Guide button.
-- Cache keys are the current profession skill and a data revision; language
-- only changes formatting and does not invalidate the calculated route.
local worker = CreateFrame("Frame")
local cache, revision, active, debounceToken = {}, 0, nil, 0
A.planCache = cache

local function StopWorker()
  active = nil
  worker:SetScript("OnUpdate", nil)
end

local function Status(skillID)
  local skill = A:Character().professions[tonumber(skillID)]
  local current = skill and tonumber(skill.rank) or 0
  local result = cache[tonumber(skillID)]
  return result, current
end

function A:GetCachedPlan(skillID)
  if not self.initialized then return nil end
  local entry, skillLevel = Status(skillID)
  if entry and entry.revision == revision and entry.level == skillLevel then
    return entry.result, entry.error
  end
  return nil
end

function A:GetCachedPrimaryPlanText(skillID)
  if not self.initialized then return self:T("CHAR_NOT_READY") end
  local valid = self:GetEligibleProfessions()
  if #valid == 0 then return self:T("NO_ELIGIBLE") end
  local selected = valid[1]
  for _, profession in ipairs(valid) do
    if tonumber(skillID) == profession.id then selected = profession; break end
  end
  self.selectedProfessionID = selected.id
  local guide = self.GetGatheringGuide and self:GetGatheringGuide(selected.id, selected.rank)
  if selected.id == 182 or selected.id == 393 then
    return guide or self:T("GUIDE_UNAVAILABLE")
  end
  local result, err = self:GetCachedPlan(selected.id)
  if not result then
    if err then return err end
    return self:T("PLAN_CALCULATING", selected.rank, 300)
  end
  local text = selected.name .. " " .. selected.rank .. "/300\n\n"
    .. self:RenderPlanSummary(selected.id, result)
  if guide then text = text .. "\n\n" .. guide end
  return text
end

local function StartNext()
  if active or not A.initialized then return end
  if not A.recipeDatabaseReady then return end
  local valid = A:GetEligibleProfessions()
  for _, prof in ipairs(valid) do
    if prof.id ~= 182 and prof.id ~= 393 then
      local cached = cache[prof.id]
      if not cached or cached.level ~= prof.rank or cached.revision ~= revision then
        local stamp, level, skillID = revision, prof.rank, prof.id
        local job = { id = skillID, level = level, revision = stamp, evaluations = 0 }
        job.thread = coroutine.create(function()
          return A:PlanProfession(skillID, 300, function()
            job.evaluations = job.evaluations + 1
            if job.evaluations % 8 == 0 then coroutine.yield() end
          end)
        end)
        active = job
        worker:SetScript("OnUpdate", function(self)
          if active ~= job or job.revision ~= revision then
            StopWorker()
            StartNext()
            return
          end
          local ok, result, err = coroutine.resume(job.thread)
          if not ok then
            cache[skillID] = {revision = stamp, level = level, error = tostring(result)}
            StopWorker()
            A:Notify("planReady")
            StartNext()
          elseif coroutine.status(job.thread) == "dead" then
            cache[skillID] = {revision = stamp, level = level, result = result, error = err}
            StopWorker()
            A:Notify("planReady")
            StartNext()
          end
        end)
        return
      end
    end
  end
end

function A:InvalidatePlanCache(reason)
  revision = revision + 1
  -- Only the current session's cache is retained. Current prices are sampled
  -- when the next plan is built; an explicit /fph scan forces a refresh.
  for id in pairs(cache) do cache[id] = nil end
  StopWorker()
  debounceToken = debounceToken + 1
  local token = debounceToken
  if C_Timer and C_Timer.After then
    C_Timer.After(1.0, function()
      if token == debounceToken then StartNext() end
    end)
  else
    StartNext()
  end
end

function A:PreparePlanCache()
  if not self.initialized then return end
  self:InvalidatePlanCache("initialize")
end

A:RegisterView("planCache", function(reason)
  if reason == "bags" or reason == "bank" or reason == "professions"
    or reason == "recipes" or reason == "recipeDB" then
    A:InvalidatePlanCache(reason)
  end
  -- planReady and language are presentation updates only.
end)
