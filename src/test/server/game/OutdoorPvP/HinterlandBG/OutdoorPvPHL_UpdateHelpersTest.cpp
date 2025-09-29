#include "gtest/gtest.h"
#include "OutdoorPvP/OutdoorPvPHL.h"
#include "WorldMock.h"
#include "Time/GameTime.h"

// Minimal test access helper using friend in the class
class OutdoorPvPHL_TestAccess {
public:
    explicit OutdoorPvPHL_TestAccess(OutdoorPvPHL& hl) : _hl(hl) {}
    bool TickTimerExpiry() { return _hl._tickTimerExpiry(); }
    void TickThresholds() { _hl._tickThresholdAnnouncements(); }
    void SetMatchEndNow() { _hl._matchEndTime = static_cast<uint32>(GameTime::GetGameTime().count()); }
    void SetResources(uint32 a, uint32 h) { _hl._ally_gathered = a; _hl._horde_gathered = h; }
    void ResetThresholdFlags() {
        _hl.IS_ABLE_TO_SHOW_MESSAGE = false;
        _hl.IS_RESOURCE_MESSAGE_A = false;
        _hl.IS_RESOURCE_MESSAGE_H = false;
        _hl.limit_A = 0; _hl.limit_H = 0;
        _hl.limit_resources_message_A = 0; _hl.limit_resources_message_H = 0;
    }
private:
    OutdoorPvPHL& _hl;
};

TEST(OutdoorPvPHL_UpdateHelpersTest, TimerExpiryNoResetIfNotReached)
{
    OutdoorPvPHL hl;
    OutdoorPvPHL_TestAccess acc(hl);
    // Seed a future end time
    hl.LoadConfig();
    hl.ForceReset();
    // Ensure not expired yet
    EXPECT_FALSE(acc.TickTimerExpiry());
}

TEST(OutdoorPvPHL_UpdateHelpersTest, ThresholdAnnouncementFlagsProgress)
{
    OutdoorPvPHL hl;
    OutdoorPvPHL_TestAccess acc(hl);
    acc.ResetThresholdFlags();
    // Drive Alliance from >300 down to 50 to hit gates in order
    acc.SetResources(300, 450);
    acc.TickThresholds();
    // After dropping to 300, Alliance resource message gate 1 is set
    EXPECT_TRUE(hl.IS_ABLE_TO_SHOW_MESSAGE);
}
