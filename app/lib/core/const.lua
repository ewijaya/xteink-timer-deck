local C={
 CAPACITY=10,MAX_SEC=86399999,MAX_INT=2147483647,DEFAULT_COUNTDOWN=10,
 NAME_MAX=16,ICON_COUNT=30,PATTERNS={'Short','Long','Short + short','Short + long'},DEFAULT_PATTERN=2,
 COUNT_MIN=1,COUNT_MAX=5,DEFAULT_COUNT=3,LATE_SEC=60,AUTO_RESET_SEC=600,CHECKPOINT_SEC=300,
 AWAKE_HORIZON_SEC=14400,KEY_DEBOUNCE_MS=250,SETTLE_MS=400,ATTEMPT_INTERVAL_MS=2000,
 IMPORT_LINES=80,CHAIN_CAPACITY=5,CHAIN_STEPS=10,CHAIN_ROUNDS=9,RECEIPTS=4,
 ICON_NAMES={'Coffee','Cooking','Eggs','Baking','Laundry','Workout','Run','Study','Focus','Nap','Medicine','Reminder','Prayer','Thanksgiving','Reading','Water','Meal','Plants','Cleaning','Bath','Bus','Parking','Meeting','Music','Mass','Whistle','Added time','Alarm plus','Love','Sex'},
}

function C.add_time(now,duration)
 if math.type(now)~='integer' or now<1 or now>C.MAX_INT or math.type(duration)~='integer' or duration<0 or duration>C.MAX_SEC then return nil,'CLOCK' end
 if duration>C.MAX_INT-now then return nil,'OVERFLOW' end
 return now+duration
end
C.COPY={
 title='TIMER DECK',empty='No timers yet',info='Device information',back='Back',
 notice='This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.',
 foundation='Timer Deck preview',pending='Timers are not available yet.',fatal='Something went wrong',retry='Try again',

 new_timer='New timer',new_watch='New stopwatch',chains='Chains',menu='Menu',settings='Settings',help='Help / About',
 start='Start',pause='Pause',resume='Resume',dismiss='Dismiss',reset='Reset',save='Save',more='More options',start_timer='Start timer',done='Done',keep='Keep',delete='Delete',edit='Edit',
 time='Time',name='Name',icon='Icon',alert='Alert',count='Count',days='Days',none='None',backspace='<',
 states={'READY','RUNNING','PAUSED','FINISHED'},primary={'Start','Pause','Resume','Dismiss'},
 appearance='Appearance',style='Style',seconds='Seconds',awake='Stay awake',flash='Screen flash',light='Light pulse',lockscreen='Lock screen',sync='Import and export',erase='Reset saved data',
 appearances={'Auto','Light','Dark'},styles={'Ion','Cobalt','Plasma','Solar'},seconds_modes={'Smart','Always','Never'},onoff={'Off','On'},use='Use this',preview='Preview',
 default_alert='Default alert',default_count='Default count',battery='Uses more battery',clear_all='Clear all',count_up='COUNT UP',limit='LIMIT REACHED',
 reset_duration='Reset to edit duration',timer_name='Timer name',watch_name='Stopwatch name',discard='Discard changes?',discard_new='Discard new timer?',
 ACTIVE='A chain is already active',CHAIN_FULL='You have 5 saved chains',
 FULL='10 items saved. Delete one to add another.',INVALID='Check the values and try again.',STALE='This item changed. Try again.',OVERFLOW="This timer would end after the device clock's limit (January 2038).",CLOCK='Set the device clock to use timers.',
 zero='Set at least 1 second',name_rule='Names use up to 16 basic Latin characters.',save_error='Could not save. Try again.',not_saved='NOT SAVED - RETRYING',clock_unset='CLOCK NOT SET',
 rollback='Clock changed. Timers restored from last saved time.',open_only='ALERTS ONLY WHILE TIMER DECK IS OPEN',
 open_strip='ALERTS ONLY WHILE TIMER DECK IS OPEN',enable_awake='Turn on Stay awake',use_lock='Use lock screen',
 coverage={'Alert: only while open','Alert: screen stays on','Alert: lock screen'},leave_title='Leave Timer Deck?',leave_text='Timers keep counting. You will not be alerted until you open Timer Deck again.',leave='Leave',stay='Stay',
 erase_text='Reset saved data? All Timer Deck items and settings will be removed.',restored='Saved data was restored from a backup.',recovery='Saved data could not be read. Try again reloads saved data. Start fresh removes old timers and settings after confirmation.',blocked='Saved data needs a newer Timer Deck version.',fresh='Start fresh',ok='OK',
 finished_away='FINISHED AWAY',queue='%d OF %d DONE',away_queue='AWAY %d OF %d',
 no_chains='No chains yet',new_chain='New chain',empty_chain='Empty chain',from_deck='From Deck timers',rounds='Rounds',steps='Steps',add_step='Add step',duplicate='Duplicate',move_up='Move up',move_down='Move down',remove='Remove',
 start_chain='Start',active_chain='View active chain',chain_busy='A chain is already active',chain_min='Add at least 2 steps',chain_max='This chain has 10 steps',chain_full='You have 5 saved chains',
 last_step='Last step',
 restart='Restart step',skip='Skip step',stop='Stop chain',stop_question='Stop this chain?',stop_delete='Stop and delete this chain?',chain_complete='Chain complete',chain_stopped='Chain stopped',again='Run again',all_chains='All chains',add='Add steps',
 file_error='Could not write the file. Try again.',import_ok='Imported definitions. See timerdeck-import-result.txt.',import_result_error='Imported, but the result file could not be written.',last25='RUNNING · LAST 25%',last10='LAST 10%',
 export='Export deck',import='Import file',exported='Saved to /AppFiles/timerdeck/timerdeck-export.txt',DUPLICATE='This file was already imported.',import_failed='Nothing was imported. See timerdeck-import-result.txt.',import_missing='No import file found. Put timerdeck-import.txt in /AppFiles/timerdeck/.',
 help_text=[[No sound
This device has no sound or vibration. Timer Deck alerts you with a screen flash and a light pulse, so keep it where you can see it.
Timers
Tap New timer, type the time, then tap Start timer. Save keeps it for later. The deck holds ten timers and stopwatches.
On the deck
Tap the button at the right of a row to start or pause it. Tap the row to open it. Swipe a row left to delete it.
Side buttons
The lower button moves to the next item. The upper button starts, pauses or dismisses it.
When a timer ends
Tap Dismiss, or Back to clear all finished timers. A finished timer you were shown clears itself after ten minutes. One you missed waits for you.
Leaving the app
Timers keep counting when you leave, lock or switch off. Alerts need Timer Deck on screen, or Timer Deck as your lock screen (Settings).
Stay awake
Stay awake keeps the reader on while a timer runs. This uses more battery.
Chains
A chain runs several steps one after another. Tap Chains, then New chain.
Clock changes
Timer Deck uses the device clock. If the clock moves forward, timers move forward with it.
Typeface
To change the typeface, open Ink App settings, then Font.]],
}

C.COPY.lock_title='Timer Deck'
C.COPY.open_app='Open Timer Deck'
C.COPY.times_up="TIME'S UP"
C.COPY.idle='No timers running'
C.COPY.finished_prefix='Finished '
C.COPY.finished_lock='finished '
C.COPY.ends='ends '
C.COPY.started='started '
C.COPY.since='since '
C.COPY.of='of '
C.COPY.next='Next: '
C.COPY.starting='Starting now: '
C.COPY.elapsed_away=' steps elapsed while away'
C.COPY.skipped=' skipped'
C.COPY.minutes=' min'
C.COPY.left=' left'
C.COPY.more_suffix=' more'
C.COPY.paused_lower='paused'
C.COPY.min_left='MIN LEFT'
C.COPY.timer_label='TIMER'
C.COPY.watch_label='WATCH'
C.COPY.preview_time='04:00'
C.COPY.keypad_hint='H : MIN : SEC'
C.COPY.line='Line '
C.COPY.import_errors={size='File exceeds 16384 bytes',utf8='Invalid UTF-8',chain='Chain needs 2–10 steps and a valid total',fields='Invalid duration, icon, alert or count',orphan='Step without a chain',watch='Invalid stopwatch',definition='Invalid chain',kind='Unknown kind',empty='No definitions found'}
C.COPY.patterns=C.PATTERNS
C.COPY.icon_names=C.ICON_NAMES

return C
