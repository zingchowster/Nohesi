Config = {}

-- ====== DRIVING / POINTS SETTINGS ======

-- Minimum speed (KM/H) before you can earn near-miss points
Config.MinSpeed = 40

-- Max distance (meters) to another vehicle to count as a near-miss
Config.MaxNearMissDistance = 7.0

-- How long the floating “+X” text stays on screen (milliseconds)
Config.FloatTime = 900

-- How long a run lasts in seconds (when it hits 0, points reset)
Config.TimerSeconds = 1449  -- 24:09

-- ====== MONEY / FRAMEWORK SETTINGS ======

-- How much money to give per point on crash/full stop
-- Example: 0.1 = every 10 points = $1
Config.MoneyPerPoint = 0.1

-- Framework mode:
--  'qbox'    = Qbox (qbx_core)
--  'qb-core' = QBCore
--  'esx'     = ESX
--  'none'    = no money / just logging
Config.Framework = 'qbox'   -- YOU: on Qbox, leave this as 'qbox'

-- How long after a crash before you can start earning points again (seconds)
-- Set to 0 if you don't want any crash timeout
Config.CrashTimeoutSeconds = 5

-- Which money account to pay into
-- ESX: 'cash' or 'bank'
-- QB/Qbox: 'cash' or 'bank' (Qbox also supports 'crypto' if you want)
Config.Account = 'cash'

-- Show a simple chat message when rewarded
Config.ShowRewardNotification = true
