-- banco-loader.lua -- Claude 29/10/2026, parere #116 §3/§8.1.
-- Esegue il config.lua INSTALLATO (/boot/lua) in flua, con il loader SIMULATO:
--   * "load ..." viene REGISTRATO, non eseguito (esito 0 = riuscito, configurabile)
--   * nextboot_conf deviato su un file del banco (argomento 1)
--   * io.open in scrittura permesso SOLO sotto BANCO, altrimenti errore
-- uso: flua banco-loader.lua <banco_dir> <nextboot_file|-> [nextboot_enable_env|-]
local BANCO, NBFILE, NBENV = arg[1], arg[2], arg[3]
assert(BANCO and BANCO:find("/mnt/linuxulator2/vm/wsl2/fbsd/h1boot/", 1, true) == 1, "BANCO fuori dal workspace")
package.path = "/boot/lua/?.lua;" .. package.path

local env = { module_path = "/boot/modules;/boot/dtb;/boot/dtb/overlays" }
if NBENV and NBENV ~= "-" then env.nextboot_enable = NBENV end
local comandi = {}
local function nbpath() return (NBFILE ~= "-") and NBFILE or (BANCO .. "/nessun-nextboot.conf") end

loader = {
  getenv = function(k) if k == "nextboot_conf" and env[k] ~= nil then return nbpath() end return env[k] end,
  setenv = function(k, v) env[k] = v; return 0 end,
  unsetenv = function(k) env[k] = nil; return 0 end,
  perform = function(s) comandi[#comandi+1] = "perform: " .. s; return 0 end,
  printc = function(s) end,
  command_error = function() return "errore simulato" end,
}
function cli_execute_unparsed(s) comandi[#comandi+1] = "cli: " .. s; return 0 end

-- io in stile loader: io.read(fh) legge tutto; scritture solo nel banco
local vero_io = io
local fio = {}
function fio.open(nome, modo)
  modo = modo or "r"
  if modo ~= "r" then
    assert(nome:sub(1, #BANCO + 1) == BANCO .. "/", "SCRITTURA FUORI DAL BANCO VIETATA: " .. nome)
  end
  return vero_io.open(nome, modo)
end
function fio.read(fh) return fh:read("a") end
function fio.write(fh, s) return fh:write(s) end
function fio.close(fh) return fh:close() end
io = fio

local config = require("config")
config.load()                 -- /boot/defaults/loader.conf -> loader_conf_files -> checkNextboot()
config.loadelf()              -- kernel + loadModule()
io = vero_io
for _, c in ipairs(comandi) do
  if c:match("vmm") or c:match("kernel") then print(c) end
end
print("ENV vmm_name=" .. tostring(env.vmm_name))
print("ENV vmm_load=" .. tostring(env.vmm_load))
print("ENV devmatch_blocklist=" .. tostring(env.devmatch_blocklist))
print("ENV nextboot_enable=" .. tostring(env.nextboot_enable))
print("ENV pptdevs=" .. tostring(env.pptdevs))
