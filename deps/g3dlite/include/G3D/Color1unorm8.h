// Minimal compatibility header: Color1unorm8
#ifndef G3D_Color1unorm8_h
#define G3D_Color1unorm8_h

#include "G3D/platform.h"

namespace G3D {

class Color1unorm8 {
public:
    float value;
    inline Color1unorm8() : value(0.0f) {}
    inline explicit Color1unorm8(float v) : value(v) {}
};

}

#endif
