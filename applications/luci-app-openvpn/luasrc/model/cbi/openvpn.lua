-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local testfullps = luci.sys.exec("ps --help 2>&1 | grep BusyBox") --check which ps do we have
local psstring = (string.len(testfullps)>0) and  "ps w" or  "ps axfw" --set command we use to get pid

local m = Map("openvpn", translate("OpenVPN"))
local s = m:section( TypedSection, "openvpn", translate("OpenVPN instances"), translate("Below is a list of configured OpenVPN instances and their current state") )
s.template = "cbi/tblsection"
s.template_addremove = "openvpn/cbi-select-input-add"
s.addremove = true
s.add_select_options = { }
s.extedit = luci.dispatcher.build_url(
	"admin", "services", "openvpn", "basic", "%s"
)

uci:load("openvpn_recipes")
uci:foreach( "openvpn_recipes", "openvpn_recipe",
	function(section)
		s.add_select_options[section['.name']] =
			section['_description'] or section['.name']
	end
)

function s.getPID(section) -- Universal function which returns valid pid # or nil
	local pid = sys.exec("%s | grep -w %s | grep openvpn | grep -v grep | awk '{print $1}'" % { psstring,section} )
	if pid and #pid > 0 and tonumber(pid) ~= nil then
		return tonumber(pid)
	else
		return nil
	end
end

function s.parse(self, section)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)

	if recipe and not s.add_select_options[recipe] then
		self.invalid_cts = true
	else
		TypedSection.parse( self, section )
	end
end

function s.create(self, name)
	local recipe = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".select"
	)
	name = luci.http.formvalue(
		luci.cbi.CREATE_PREFIX .. self.config .. "." ..
		self.sectiontype .. ".text"
	)
	if string.len(name)>3 and not name:match("[^a-zA-Z0-9_]") then
		uci:section(
			"openvpn", "openvpn", name,
			uci:get_all( "openvpn_recipes", recipe )
		)

		uci:delete("openvpn", name, "_role")
		uci:delete("openvpn", name, "_description")
		uci:save("openvpn")

		luci.http.redirect( self.extedit:format(name) )
	else
		self.invalid_cts = true
	end
end


s:option( Flag, "enabled", translate("Enabled") )

local active = s:option( DummyValue, "_active", translate("Started") )
function active.cfgvalue(self, section)
	local pid = s.getPID(section)
	if pid ~= nil then
		return (sys.process.signal(pid, 0))
			and translatef("yes (%i)", pid)
			or  translate("no")
	end
	return translate("no")
end

local updown = s:option( Button, "_updown", translate("Start/Stop") )
updown._state = false
updown.redirect = luci.dispatcher.build_url(
	"admin", "services", "openvpn"
)
function updown.cbid(self, section)
	local pid = s.getPID(section)
	self._state = pid ~= nil and sys.process.signal(pid, 0)
	self.option = self._state and "stop" or "start"
	return AbstractValue.cbid(self, section)
end
function updown.cfgvalue(self, section)
	self.title = self._state and "stop" or "start"
	self.inputstyle = self._state and "reset" or "reload"
end
function updown.write(self, section, value)
	if self.option == "stop" then
		local pid = s.getPID(section)
		if pid ~= nil then
			sys.process.signal(pid,15)
		end
	else
		luci.sys.call("/etc/init.d/openvpn start %s" % section)
	end
	luci.http.redirect( self.redirect )
end


local port = s:option( DummyValue, "port", translate("Port") )
function port.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "1194"
end

local proto = s:option( DummyValue, "proto", translate("Protocol") )
function proto.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	return val or "udp"
end

local o = m:section(TypedSection, "openvpnclient", translate("An easy config OpenVPN Client Web-UI"))
o.anonymous = true
o.addremove = false

o:tab("code",  translate("自定义客户端代码"))
local conf = "/etc/openvpn/my-vpn.conf"
local NXFS = require "nixio.fs"
d = o:taboption("code", TextValue, "conf")
d.description = translate("想要加入到.ovpn文件里的代码,如果使用帐号密码验证则需要加入auth-user-pass pass.txt")
d.rows = 13
d.wrap = "off"
d.cfgvalue = function(self, section)
	return NXFS.readfile(conf) or ""
end
d.write = function(self, section, value)
	NXFS.writefile(conf, value:gsub("\r\n", "\n"))
end

o:tab("pwdcode",  translate("帐号密码"))
local pwdconf = "/etc/openvpn/pass.txt"
local NXFS = require "nixio.fs"
d = o:taboption("pwdcode", TextValue, "pwdconf")
d.description = translate("编辑 pass.txt")
d.rows = 13
d.wrap = "off"
d.cfgvalue = function(self, section)
	return NXFS.readfile(pwdconf) or ""
end
d.write = function(self, section, value)
	NXFS.writefile(pwdconf, value:gsub("\r\n", "\n"))
end

return m
