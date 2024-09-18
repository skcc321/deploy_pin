# frozen_string_literal: true

# 75371573753754:III
# task_title: task with explicit wait
# affected_areas: none

# === task code goes down here ===
parallel_each(1..2, progress: 2) {}
