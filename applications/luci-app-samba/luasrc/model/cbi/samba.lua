-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local state_msg = ""
local running=(luci.sys.call("pidof smbd > /dev/null") == 0)

if running then
	state_msg = "<b><font color=\"green\">" .. translate("smbd 运行中") .. "</font></b>"
else
	state_msg = "<b><font color=\"red\">" .. translate("smbd 未运行") .. "</font></b>"
end

local state_msg1 = ""
local running1=(luci.sys.call("pidof nmbd > /dev/null") == 0)

if running1 then
	state_msg1 = "<b><font color=\"blue\">" .. translate("nmbd 运行中") .. "</font></b>"
else
	state_msg1 = "<b><font color=\"red\">" .. translate("nmbd 未运行") .. "</font></b>"
end

m = Map("samba", translate("Network Shares"),
translate("状态：").. state_msg.. state_msg1)

s = m:section(TypedSection, "samba", "Samba")
s.anonymous = true

s:tab("general",  translate("General Settings"))
s:tab("template", translate("Edit Template"))

enable = s:taboption("general", Flag, "enabled", translate("Enable"), translate("Enable Samba"))
enable.rmempty = false
enable.optional = false

function enable.write(self, section, value)
	if value == "0" then
		os.execute("/etc/init.d/samba disable")
		os.execute("/etc/init.d/samba stop")
	else
		os.execute("/etc/init.d/samba enable")
	end
	Flag.write(self, section, value)
end
s:taboption("general", Value, "name", translate("Hostname"))
s:taboption("general", Value, "description", translate("Description"))
s:taboption("general", Value, "workgroup", translate("Workgroup"))
h = s:taboption("general", Flag, "homes", translate("Share home-directories"),
        translate("Allow system users to reach their home directories via " ..
                "network shares"))
h.rmempty = false

tmpl = s:taboption("template", Value, "_tmpl",
	translate("Edit the template that is used for generating the samba configuration."), 
	translate("This is the content of the file '/etc/samba/smb.conf.template' from which your samba configuration will be generated. " ..
		"Values enclosed by pipe symbols ('|') should not be changed. They get their values from the 'General Settings' tab."))

tmpl.template = "cbi/tvalue"
tmpl.rows = 20

function tmpl.cfgvalue(self, section)
	return nixio.fs.readfile("/etc/samba/smb.conf.template")
end

function tmpl.write(self, section, value)
	value = value:gsub("\r\n?", "\n")
	nixio.fs.writefile("//etc/samba/smb.conf.template", value)
end


s = m:section(TypedSection, "sambashare", translate("Shared Directories")
  , translate("Please add directories to share. Each directory refers to a folder on a mounted device."))
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"

s:option(Value, "name", translate("Name"))
pth = s:option(Value, "path", translate("Path"))
if nixio.fs.access("/etc/config/fstab") then
        pth.titleref = luci.dispatcher.build_url("admin", "system", "fstab")
end

s:option(Value, "users", translate("Allowed users")).rmempty = true

ro = s:option(Flag, "read_only", translate("Read-only"))
ro.rmempty = false
ro.enabled = "yes"
ro.disabled = "no"

br = s:option(Flag, "browseable", translate("Browseable"))
br.rmempty = false
br.default = "yes"
br.enabled = "yes"
br.disabled = "no"

go = s:option(Flag, "guest_ok", translate("Allow guests"))
go.rmempty = false
go.enabled = "yes"
go.disabled = "no"

cm = s:option(Value, "create_mask", translate("Create mask"),
        translate("Mask for new files"))
cm.rmempty = true
cm.size = 4

dm = s:option(Value, "dir_mask", translate("Directory mask"),
        translate("Mask for new directories"))
dm.rmempty = true
dm.size = 4


return m
