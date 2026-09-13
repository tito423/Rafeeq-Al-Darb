import xml.etree.ElementTree as ET
import subprocess
import time
import sys

def tap_text(text):
    subprocess.run(["adb", "-s", "emulator-5554", "shell", "uiautomator", "dump", "/sdcard/window_dump.xml"], check=True)
    subprocess.run(["adb", "-s", "emulator-5554", "pull", "/sdcard/window_dump.xml", "window_dump.xml"], capture_output=True, check=True)
    
    tree = ET.parse("window_dump.xml")
    root = tree.getroot()
    
    for node in root.iter("node"):
        content_desc = node.get("content-desc", "")
        text_attr = node.get("text", "")
        if text in content_desc or text in text_attr:
            bounds = node.get("bounds")
            # format is [x1,y1][x2,y2]
            bounds = bounds.replace("][", ",").replace("[", "").replace("]", "")
            x1, y1, x2, y2 = map(int, bounds.split(","))
            cx = (x1 + x2) // 2
            cy = (y1 + y2) // 2
            print(f"Found '{text}' at ({cx}, {cy}), tapping...")
            subprocess.run(["adb", "-s", "emulator-5554", "shell", "input", "tap", str(cx), str(cy)], check=True)
            time.sleep(2)
            return True
    
    print(f"Could not find '{text}'")
    return False

if __name__ == "__main__":
    if len(sys.argv) > 1:
        tap_text(sys.argv[1])
