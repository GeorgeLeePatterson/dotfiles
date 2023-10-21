-- SSH domains
local _, domains = pcall(require, "ssh-domains")
return {
    ssh_domains = domains or {},
}
