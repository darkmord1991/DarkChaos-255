if not InGlue then
	function InGlue()
		return false
	end
end

-- Referenced by the (retail) PortraitFrameTemplate2 in SharedUIPanelTemplates.xml,
-- which isn't stock on 3.3.5. Defined here (loads before that XML) so the template
-- parses without an "Unknown function" warning.
if not PortraitFrameCloseButton_OnClick then
	function PortraitFrameCloseButton_OnClick(self)
		local parent = self and self.GetParent and self:GetParent()
		if parent and HideUIPanel then
			HideUIPanel(parent)
		end
	end
end
