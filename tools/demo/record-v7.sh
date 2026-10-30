#!/bin/zsh
# Record and assemble the v7 walkthroughs end to end.
#
#   tools/demo/record-v7.sh ipad      # five iPad takes  → NoteStalgia-Walkthrough-v7.mp4
#   tools/demo/record-v7.sh mobile    # six iPhone takes → NoteStalgia-Walkthrough-v7-mobile.mp4
#   tools/demo/record-v7.sh all       # both, iPad first
#
# Needs: the demo Worker reachable (codes exposed), edge-tts for the voice, ~6 GB free disk, and nothing else using
# the simulators — only one device may run at a time on an 8 GB Mac, and touching the simulator during a take
# makes the take fail. Run it headless: quit Simulator.app and detach the Claude simulator panel first (with
# Simulator.app open an iPad shows a number-pad popover over the form and the typing goes wrong). The pace follows the voice: narration.py writes how long each line takes, and the tests wait
# for the line spoken at the last marker before moving on (see DemoWalkthroughUITests.hold).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO"
WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK"
what="${1:-all}"
IPAD="${DEMO_IPAD_UDID:-675E347E-4E0B-4A86-B84F-E97EFCE9FDFF}"     # iPad Air 11 Demo
IPHONE="${DEMO_IPHONE_UDID:-D7EA0745-6C3A-455A-A87D-91DA99E6B92B}" # iPhone 17 Pro
export DEMO_AUDIO_DEVICE=""                                        # video only; the soundtrack is rebuilt from the log
export TEST_RUNNER_API_BASE_URL="${TEST_RUNNER_API_BASE_URL:-https://notestalgia-api.fitraclesub.workers.dev}"
export TEST_RUNNER_DEMO_NARRATION_FILE="$WORK/narration-durations.json"
export DEMO_PACE="${DEMO_PACE:-1}"

echo "== voice: rendering every line and writing its duration"
python3 tools/demo/pipeline/narration.py --durations "$TEST_RUNNER_DEMO_NARRATION_FILE"

boot_only() {   # one simulator at a time
  for other in $(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}'); do
    [[ "$other" == "$1" ]] || xcrun simctl shutdown "$other" || true
  done
  xcrun simctl boot "$1" 2>/dev/null || true
  xcrun simctl bootstatus "$1" -b > /dev/null 2>&1 || true
}

record() {      # <udid> <test:take>...
  local udid="$1"; shift
  boot_only "$udid"
  for pair in "$@"; do
    echo "== take ${pair##*:} (${pair%%:*})"
    DEMO_UDID="$udid" tools/demo/walkthrough.sh "${pair%%:*}" "${pair##*:}"
  done
}

if [[ "$what" == "ipad" || "$what" == "all" ]]; then
  tools/demo/reset-backend.sh
  record "$IPAD" \
    testStoryPartE_LiveBackend:e_live testStoryPartF_OnlineDiscovery:f_discovery \
    testStoryPartH_GroupSession:h_group testStoryPartG_GroupProgramme:g_admin testStoryPartI_Onboarding:i_onboarding
  python3 tools/demo/pipeline/build_v7.py
fi
if [[ "$what" == "mobile" || "$what" == "all" ]]; then
  tools/demo/reset-backend.sh
  record "$IPHONE" \
    testMobileA_Request:m_request testMobileB_SetupOrganisationHomesTeam:m_setup1 \
    testMobileC_SetupResidentsIpadsReady:m_setup2 testMobileD_ColleagueJoins:m_join \
    testMobileE_HomeAdminDashboard:m_admin testMobileF_ManageTheTeam:m_team
  python3 tools/demo/pipeline/build_v7_mobile.py
fi
echo "done"
