#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

xammpPath := A_ScriptDir . "\xampp"
httpd := xammpPath . "\apache\bin\httpd.exe"

if (FileExist(httpd) && A_OSVersion != "WIN_XP" && A_IsAdmin) {
	try {
		FwPolicy2 := ComObjCreate("HNetCfg.FwPolicy2")
		ruleAlreadyExists := False
		Rules := FwPolicy2.Rules
		for rule in Rules
			if (rule.ApplicationName = httpd) {
				ruleAlreadyExists := True
				break
			}
		if (!ruleAlreadyExists) {
			NewRule := ComObjCreate("HNetCfg.FWRule"), NewRuleUdp := ComObjCreate("HNetCfg.FWRule")
			NewRule.Description                 := NewRule.Name := "httpd.exe"
			NewRule.ApplicationName             := Format("{:L}", httpd) ; for some reason, the paths are made lower-case by Windows when it adds a firewall rule itself
			NewRule.Protocol                    := NET_FW_IP_PROTOCOL_TCP := 6
			NewRule.RemoteAddresses             := NewRule.LocalAddresses := NewRule.RemoteAddresses := NewRule.RemotePorts := "*"
			NewRule.Direction                   := NET_FW_RULE_DIR_IN := 1
			NewRule.InterfaceTypes              := "All"
			NewRule.Enabled                     := True
			NewRule.Profiles                    := NET_FW_PROFILE2_PRIVATE := 0x2 | NET_FW_PROFILE2_PUBLIC := 0x4 ; | NET_FW_PROFILE2_DOMAIN := 0x1 / NET_FW_PROFILE2_ALL := 0x7fffffff
			NewRule.Action                      := NET_FW_ACTION_ALLOW := 1

			NewRuleUdp.Description                 := NewRuleUdp.Name := NewRule.Name
			NewRuleUdp.ApplicationName             := NewRule.ApplicationName
			NewRuleUdp.Protocol                    := NET_FW_IP_PROTOCOL_UDP := 17
			NewRuleUdp.RemoteAddresses             := NewRuleUdp.LocalAddresses := NewRuleUdp.RemoteAddresses := NewRuleUdp.RemotePorts := NewRule.RemotePorts
			NewRuleUdp.Direction                   := NewRule.Direction
			NewRuleUdp.InterfaceTypes              := NewRule.InterfaceTypes
			NewRuleUdp.Enabled                     := NewRule.Enabled
			NewRuleUdp.Profiles                    := NewRule.Profiles
			NewRuleUdp.Action                      := NewRule.Action
			
			Rules.Add(NewRule), Rules.Add(NewRuleUdp)
		}
	}
}