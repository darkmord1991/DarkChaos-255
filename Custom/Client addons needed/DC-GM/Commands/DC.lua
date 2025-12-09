function AzerothAdmin:CreateDCSection()
  FrameLib:BuildFrame({
    name = "ma_dcframe",
    group = "dc",
    parent = ma_midframe,
    texture = {
      color = {0, 0, 0, 0}
    },
    size = {
      width = 750,
      height = 254
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 0,
      offY = 0
    },
    inherits = nil
  })

  FrameLib:BuildButton({
    name = "ma_dc_gomove_btn",
    group = "dc",
    parent = ma_dcframe,
    texture = {
      name = "ma_dc_gomove_btn_texture",
      color = {0.2, 0.2, 0.2, 1},
      gradient = {
        orientation = "vertical",
        min = {0.1, 0.1, 0.1, 1},
        max = {0.2, 0.2, 0.2, 1}
      }
    },
    size = {
      width = 150,
      height = 25
    },
    setpoint = {
      pos = "TOPLEFT",
      offX = 10,
      offY = -10
    },
    text = "GOMove UI"
  })
  AzerothAdmin:PrepareScript(ma_dc_gomove_btn, "Open GOMove UI", function() SlashCmdList.GOMOVE("") end)
end
