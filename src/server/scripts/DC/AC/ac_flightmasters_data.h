#pragma once
#include <string>

// Note: this header expects to be included after engine headers that define
// `Position`, `uint8`, etc. It's placed in the same namespace as the AI.
namespace DC_AC_Flight
{
// Scenic route data for Azshara Crater (kept inline to avoid an extra TU)
inline Position const kPath[] = {
    { 137.1860f, 954.9300f, 327.5140f, 0.327798f },  // acfm1
    { 269.8730f, 827.0230f, 289.0940f, 5.185540f },  // acfm2
    { 267.8360f, 717.6040f, 291.3220f, 4.173980f },  // acfm3
    { 198.4970f, 627.0770f, 293.5140f, 4.087590f },  // acfm4
    { 117.5790f, 574.0660f, 297.4290f, 2.723360f },  // acfm5
    {  11.1490f, 598.8440f, 284.8780f, 4.851790f },  // acfm6
    {  33.1020f, 542.8160f, 291.3630f, 5.169860f },  // acfm7
    {  42.6800f, 499.4120f, 315.3510f, 5.323030f },  // acfm8
    {  64.4858f, 485.8540f, 328.2840f, 5.758730f },  // acfm9
    {  80.5593f, 444.3300f, 338.0710f, 4.785630f },  // acfm10
    {  69.1581f, 403.6100f, 335.2570f, 4.257060f },  // acfm11
    {  36.7813f, 383.8160f, 320.9390f, 3.294960f },  // acfm12
    {   4.0747f, 388.9040f, 310.3970f, 2.729470f },  // acfm13
    { -12.7592f, 405.7640f, 307.0690f, 2.060310f },  // acfm14
    { -18.4005f, 416.3530f, 307.4260f, 2.060310f },  // acfm15
    // Additional nodes
    {  -20.3265f, 419.0570f, 308.2240f, 5.91598f  }, // acfm19
    {    0.70243f,403.3250f, 313.2740f, 5.59253f  }, // acfm20
    {   69.2940f, 343.8420f, 308.4380f, 5.55719f  }, // acfm21
    {  139.4370f, 304.9340f, 302.6710f, 5.87920f  }, // acfm22
    {  197.2580f, 251.1890f, 294.5420f, 5.32078f  }, // acfm23
    {  253.7330f, 174.3900f, 275.8360f, 5.54068f  }, // acfm24
    {  250.0990f, 108.0630f, 266.0210f, 5.06001f  }, // acfm25
    {  288.0720f,  35.7399f, 288.2950f, 5.28778f  }, // acfm26
    {  339.6580f, -39.0153f, 299.9640f, 5.07650f  }, // acfm27
    {  348.2650f, -99.4286f, 298.4710f, 4.86836f  }, // acfm28
    {  369.2020f,-154.2740f, 299.7370f, 5.45034f  }, // acfm29
    {  417.6860f,-179.9230f, 300.9320f, 6.21375f  }, // acfm30
    {  474.4610f,-156.4080f, 302.2410f, 0.538461f }, // acfm31
    {  530.1590f, -71.5742f, 295.4710f, 1.32386f  }, // acfm32
    {  563.7880f,  51.9529f, 288.2520f, 1.23747f  }, // acfm33
    {  601.5580f, 112.9140f, 282.8300f, 0.852621f }, // acfm34
    {  620.9780f, 126.0180f, 282.5800f, 4.24868f  }, // acfm35
    // Newly added extended waypoints
    {  623.2570f, 125.9740f, 282.3190f, 5.18330f  }, // acfm40
    {  626.1070f, 115.0240f, 284.6130f, 5.26654f  }, // acfm41
    {  656.0900f, 107.7920f, 282.0520f, 0.0719209f}, // acfm42
    {  684.2030f, 109.8170f, 283.2330f, 0.0719209f}, // acfm43
    {  702.2520f, 111.1180f, 292.5510f, 0.342098f }, // acfm44
    {  733.9850f, 135.3200f, 294.2670f, 1.05367f  }, // acfm45
    {  741.5040f, 164.3300f, 295.5340f, 1.39060f  }, // acfm46
    {  767.9480f, 227.9190f, 298.4810f, 1.08823f  }, // acfm47
    {  813.1940f, 285.8880f, 301.7320f, 6.21452f  }, // acfm48
    {  897.0600f, 294.0240f, 321.7490f, 6.24751f  }, // acfm49
    {  961.4010f, 280.4980f, 367.4450f, 5.97262f  }, // acfm50
    { 1059.9800f, 237.4870f, 384.4350f, 5.46057f  }, // acfm51
    { 1079.8700f, 190.0100f, 379.8740f, 4.87623f  }, // acfm52
    { 1085.7700f, 129.3060f, 368.2810f, 4.67989f  }, // acfm53
    { 1070.5100f,  86.2029f, 351.1760f, 4.25813f  }, // acfm54
    { 1051.0700f,  39.0495f, 334.1950f, 4.45447f  }, // acfm55
    { 1049.7600f,  13.1380f, 330.9040f, 4.90214f  }, // acfm56
    { 1070.1400f, -23.4705f, 330.2390f, 3.66827f  }, // acfm57
    {   73.2833f, 938.1900f, 341.0360f, 3.309180f }   // acfm0 (Startcamp, final)
};

inline constexpr uint8 kPathLength = static_cast<uint8>(sizeof(kPath) / sizeof(kPath[0]));
inline constexpr uint8 kIndex_startcamp = static_cast<uint8>(kPathLength - 1);
inline uint8 LastScenicIndex()
{
    return static_cast<uint8>(kPathLength - 2);
}
inline constexpr uint8 kIndex_acfm15 = 14;
inline constexpr uint8 kIndex_acfm19 = 15;
inline constexpr uint8 kIndex_acfm35 = 31;
inline constexpr uint8 kIndex_acfm40 = 32;
inline constexpr uint8 kIndex_acfm57 = 49;

inline std::string NodeLabel(uint8 idx)
{
    if (idx == kIndex_startcamp)
        return "Startcamp";
    if (idx <= 14)
        return std::string("acfm") + std::to_string(static_cast<unsigned>(idx + 1));
    if (idx >= 15 && idx <= 31)
    {
        unsigned n = 19u + static_cast<unsigned>(idx - 15);
        return std::string("acfm") + std::to_string(n);
    }
    if (idx >= 32 && idx <= 48)
    {
        unsigned n = 40u + static_cast<unsigned>(idx - 32);
        return std::string("acfm") + std::to_string(n);
    }
    if (idx == 49)
        return std::string("acfm57");
    return std::string("acfm?");
}

} // namespace DC_AC_Flight
