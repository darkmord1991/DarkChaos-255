#!/bin/bash
# Enable core dumps for AzerothCore crash debugging

echo "Enabling core dumps for crash debugging..."

# 1. Set unlimited core dump size
ulimit -c unlimited

# 2. Configure core dump pattern (saves to /tmp with timestamp)
sudo sysctl -w kernel.core_pattern=/tmp/core-%e-%p-%t

# 3. Verify settings
echo "Core dump size limit: $(ulimit -c)"
echo "Core dump pattern: $(cat /proc/sys/kernel/core_pattern)"

# 4. Install debugging tools if not present
if ! command -v gdb &> /dev/null; then
    echo "Installing GDB debugger..."
    sudo apt-get update
    sudo apt-get install -y gdb
fi

# 5. Compile with debug symbols (add to CMake command)
echo ""
echo "To enable debug symbols, rebuild with:"
echo "cmake ../ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/home/wowcore/azerothcore/env/dist"
echo ""
echo "Core dumps will be saved to /tmp/core-*"
echo "To analyze a crash: gdb /path/to/worldserver /tmp/core-worldserver-PID-TIMESTAMP"
