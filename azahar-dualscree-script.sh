#!/bin/bash

# Azahar Fullscreen Script for Steam Deck
# Makes Azahar screens fullscreen on correct displays
# Bottom screen -> Steam Deck, Top screen -> External Monitor

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    if ! command -v xdotool &> /dev/null; then
        print_error "xdotool is required but not installed"
        print_status "Install with: sudo pacman -S xdotool"
        exit 1
    fi
    
    if ! command -v wmctrl &> /dev/null; then
        print_warning "wmctrl not found - install for better window management"
        print_warning "Install with: sudo pacman -S wmctrl"
    fi
}

# Get display information with coordinates
get_displays() {
    print_status "Getting display information with coordinates..."
    
    # Get display info with geometry
    DISPLAY_INFO=$(xrandr --query | grep " connected")
    
    # Find primary display
    PRIMARY_DISPLAY=$(echo "$DISPLAY_INFO" | grep "primary" | cut -d' ' -f1)
    PRIMARY_GEOMETRY=$(echo "$DISPLAY_INFO" | grep "primary" | grep -o '[0-9]*x[0-9]*+[0-9]*+[0-9]*')
    
    # Find secondary display (first non-primary)
    SECONDARY_DISPLAY=$(echo "$DISPLAY_INFO" | grep -v "primary" | head -1 | cut -d' ' -f1)
    SECONDARY_GEOMETRY=$(echo "$DISPLAY_INFO" | grep -v "primary" | head -1 | grep -o '[0-9]*x[0-9]*+[0-9]*+[0-9]*')
    
    if [ -z "$SECONDARY_DISPLAY" ]; then
        print_error "Only one display detected. Please connect your external monitor."
        exit 1
    fi
    
    # Parse coordinates
    if [ ! -z "$PRIMARY_GEOMETRY" ]; then
        PRIMARY_X=$(echo $PRIMARY_GEOMETRY | cut -d'+' -f2)
        PRIMARY_Y=$(echo $PRIMARY_GEOMETRY | cut -d'+' -f3)
        PRIMARY_WIDTH=$(echo $PRIMARY_GEOMETRY | cut -d'x' -f1)
        PRIMARY_HEIGHT=$(echo $PRIMARY_GEOMETRY | cut -d'x' -f2 | cut -d'+' -f1)
    fi
    
    if [ ! -z "$SECONDARY_GEOMETRY" ]; then
        SECONDARY_X=$(echo $SECONDARY_GEOMETRY | cut -d'+' -f2)
        SECONDARY_Y=$(echo $SECONDARY_GEOMETRY | cut -d'+' -f3)
        SECONDARY_WIDTH=$(echo $SECONDARY_GEOMETRY | cut -d'x' -f1)
        SECONDARY_HEIGHT=$(echo $SECONDARY_GEOMETRY | cut -d'x' -f2 | cut -d'+' -f1)
    fi
    
    print_status "Primary Display: $PRIMARY_DISPLAY (${PRIMARY_WIDTH}x${PRIMARY_HEIGHT}+${PRIMARY_X}+${PRIMARY_Y})"
    print_status "Secondary Display: $SECONDARY_DISPLAY (${SECONDARY_WIDTH}x${SECONDARY_HEIGHT}+${SECONDARY_X}+${SECONDARY_Y})"
    
    return 0
}

# Find Azahar windows by specific names
find_azahar_windows() {
    print_status "Looking for Azahar primary and secondary windows..."
    
    # Look for primary window
    PRIMARY_WINDOW=$(xdotool search --name "primary window" 2>/dev/null || true)
    if [ -z "$PRIMARY_WINDOW" ]; then
        PRIMARY_WINDOW=$(xdotool search --name "Primary Window" 2>/dev/null || true)
    fi
    
    # Look for secondary window
    SECONDARY_WINDOW=$(xdotool search --name "secondary window" 2>/dev/null || true)
    if [ -z "$SECONDARY_WINDOW" ]; then
        SECONDARY_WINDOW=$(xdotool search --name "Secondary Window" 2>/dev/null || true)
    fi
    
    # Debug: Show all Azahar-related windows
    print_status "Debug: All windows containing 'window':"
    xdotool search --name "window" 2>/dev/null | while read wid; do
        title=$(xdotool getwindowname "$wid" 2>/dev/null || echo "No title")
        echo "  Window ID: $wid, Title: '$title'"
    done
    
    if [ -z "$PRIMARY_WINDOW" ] && [ -z "$SECONDARY_WINDOW" ]; then
        print_error "No Azahar windows found. Make sure Azahar is running with separate windows mode."
        return 1
    fi
    
    if [ ! -z "$PRIMARY_WINDOW" ]; then
        print_status "Found primary window: $PRIMARY_WINDOW"
    else
        print_warning "Primary window not found"
    fi
    
    if [ ! -z "$SECONDARY_WINDOW" ]; then
        print_status "Found secondary window: $SECONDARY_WINDOW"
    else
        print_warning "Secondary window not found"
    fi
    
    return 0
}

# Clear window states (remove fullscreen, maximize, etc.)
clear_window_states() {
    print_status "Clearing previous window states..."
    
    if [ ! -z "$PRIMARY_WINDOW" ]; then
        print_status "Resetting primary window state..."
        if command -v wmctrl &> /dev/null; then
            wmctrl -i -r "$PRIMARY_WINDOW" -b remove,fullscreen,maximized_vert,maximized_horz,above,below
        fi
        # Also try with xdotool to exit fullscreen
        xdotool windowactivate "$PRIMARY_WINDOW"
        sleep 0.2
        xdotool key Escape F11 Escape
        sleep 0.3
    fi
    
    if [ ! -z "$SECONDARY_WINDOW" ]; then
        print_status "Resetting secondary window state..."
        if command -v wmctrl &> /dev/null; then
            wmctrl -i -r "$SECONDARY_WINDOW" -b remove,fullscreen,maximized_vert,maximized_horz,above,below
        fi
        # Also try with xdotool to exit fullscreen
        xdotool windowactivate "$SECONDARY_WINDOW"
        sleep 0.2
        xdotool key Escape F11 Escape
        sleep 0.3
    fi
    
    print_status "Window states cleared"
}

# Move window to specific display and make fullscreen using X11
move_and_fullscreen_x11() {
    local window_id="$1"
    local target_x="$2"
    local target_y="$3"
    local target_width="$4"
    local target_height="$5"
    local window_name="$6"
    
    print_status "Processing $window_name..."
    print_status "Target: ${target_width}x${target_height}+${target_x}+${target_y}"
    
    # Clear this specific window's state first
    if command -v wmctrl &> /dev/null; then
        wmctrl -i -r "$window_id" -b remove,fullscreen,maximized_vert,maximized_horz,above,below
        sleep 0.3
    fi
    
    # Make sure window is active and try to exit any existing fullscreen
    xdotool windowactivate "$window_id"
    sleep 0.2
    xdotool key Escape
    sleep 0.2
    
    # Move window to target display
    print_status "Moving $window_name to position..."
    xdotool windowmove "$window_id" "$target_x" "$target_y"
    sleep 0.3
    
    # Resize to full display size
    print_status "Resizing $window_name..."
    xdotool windowsize "$window_id" "$target_width" "$target_height"
    sleep 0.3
    
    # Make fullscreen using wmctrl
    print_status "Making $window_name fullscreen..."
    if command -v wmctrl &> /dev/null; then
        wmctrl -i -r "$window_id" -b add,fullscreen
    else
        xdotool key F11
    fi
    
    sleep 0.2
    print_status "$window_name setup complete"
}

# Position Azahar primary and secondary windows
position_azahar_screens() {
    # Primary window goes to secondary display (external monitor)
    if [ ! -z "$PRIMARY_WINDOW" ]; then
        move_and_fullscreen_x11 "$PRIMARY_WINDOW" "$SECONDARY_X" "$SECONDARY_Y" "$SECONDARY_WIDTH" "$SECONDARY_HEIGHT" "primary window"
    fi
    
    # Secondary window goes to primary display (Steam Deck)
    if [ ! -z "$SECONDARY_WINDOW" ]; then
        move_and_fullscreen_x11 "$SECONDARY_WINDOW" "$PRIMARY_X" "$PRIMARY_Y" "$PRIMARY_WIDTH" "$PRIMARY_HEIGHT" "secondary window"
    fi
}

# Main function to set up fullscreen
setup_fullscreen() {
    print_status "Setting up Azahar fullscreen on correct displays..."
    
    check_dependencies
    get_displays
    
    # Find Azahar windows
    if ! find_azahar_windows; then
        return 1
    fi
    
    # Move windows to correct displays and make fullscreen
    position_azahar_screens
    
    print_status "Azahar fullscreen setup complete!"
    print_status "Primary window → External Monitor (fullscreen)"
    print_status "Secondary window → Steam Deck (fullscreen)"
}

# Main script logic
case "$1" in
    "monitor"|"m")
        monitor_mode
        ;;
    "info"|"i")
        check_dependencies
        get_displays
        ;;
    "help"|"h"|"--help"|"-h")
        show_help
        ;;
    *)
        # Default action: setup fullscreen
        setup_fullscreen
        ;;
esac
