-- SSH domains
local ok, domains = pcall(require, "ssh-domains")

if ok then
	return {
		ssh_domains = domains or {},
	}
else
	return {}
end
