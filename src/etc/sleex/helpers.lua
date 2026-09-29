HOME = os.getenv("HOME")

function is_file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   else
      return false
   end
end

function create_if_not_exists(path)
   if not is_file_exists(path) then
      os.execute("mkdir -p \"$(dirname \"" .. path .. "\")\"")
      os.execute("echo '-- This file will not be overwritten across sleex updates.' > \"" .. path .. "\"")
      return true
   end
   return false
end

function safe_load(path)
    local absolute_path = path:gsub("^~", HOME)

    local file_to_check = absolute_path .. ".lua"
    local file = io.open(file_to_check, "r")
    if file then
        file:close()

        dofile(file_to_check)
    else
         create_if_not_exists(file_to_check)
    end
end