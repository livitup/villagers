import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Connects to data-controller="shift-signup"
export default class extends Controller {
  static targets = ["modal", "startTime", "endTimeSelect", "durationDisplay", "submitBtn", "programName", "loading", "minimumNote", "error"]
  static values = {
    availableTimeslotsUrl: String,
    bulkCreateUrl: String,
    timeslotId: Number
  }

  connect() {
    // Controller connected
  }

  getModal() {
    if (!this._modal) {
      this._modal = new bootstrap.Modal(this.modalTarget)
    }
    return this._modal
  }

  async openModal(event) {
    event.preventDefault()

    const button = event.currentTarget
    this.timeslotIdValue = button.dataset.timeslotId

    // Show loading state
    this.loadingTarget.classList.remove("d-none")
    this.submitBtnTarget.disabled = true

    try {
      // Fetch available timeslots
      const url = `${this.availableTimeslotsUrlValue}?timeslot_id=${this.timeslotIdValue}`
      const response = await fetch(url, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (!response.ok) throw new Error("Failed to load timeslot data")

      const data = await response.json()
      this.populateModal(data)
      this.getModal().show()
    } catch (error) {
      console.error("Error loading timeslot data:", error)
      alert("Failed to load shift options. Please try again.")
    } finally {
      this.loadingTarget.classList.add("d-none")
      this.submitBtnTarget.disabled = false
    }
  }

  populateModal(data) {
    // Clear any prior validation error
    this.hideError()

    // Set start time display
    this.startTimeTarget.textContent = data.start_time_display
    this.startTimeTarget.dataset.isoTime = data.start_time

    // Set program name
    this.programNameTarget.textContent = data.program_name

    // Conference shift block size (defaults to 15 if not provided). Durations
    // must be a whole number of blocks. Stored so submit() can guard too.
    this.minDuration = data.minimum_shift_duration || 15

    // Tell the user the block size for this conference (only when > 15 min)
    if (this.hasMinimumNoteTarget) {
      if (this.minDuration > 15) {
        this.minimumNoteTarget.textContent = `Shifts are booked in ${this.formatDuration(this.minDuration)} blocks.`
        this.minimumNoteTarget.classList.remove("d-none")
      } else {
        this.minimumNoteTarget.classList.add("d-none")
      }
    }

    // Populate end time options
    this.endTimeSelectTarget.innerHTML = ""

    // Add duration-based options
    const durations = [
      { minutes: 15, label: "15 minutes" },
      { minutes: 30, label: "30 minutes" },
      { minutes: 45, label: "45 minutes" },
      { minutes: 60, label: "1 hour" },
      { minutes: 90, label: "1.5 hours" },
      { minutes: 120, label: "2 hours" },
      { minutes: 150, label: "2.5 hours" },
      { minutes: 180, label: "3 hours" },
      { minutes: 210, label: "3.5 hours" },
      { minutes: 240, label: "4 hours" },
      { minutes: 270, label: "4.5 hours" },
      { minutes: 300, label: "5 hours" },
      { minutes: 330, label: "5.5 hours" },
      { minutes: 360, label: "6 hours" }
    ]

    // Find max available duration
    const maxDuration = data.available_end_times.length > 0
      ? data.available_end_times[data.available_end_times.length - 1].duration_minutes
      : 0

    const minDuration = this.minDuration

    // Create option group for durations
    const durationGroup = document.createElement("optgroup")
    durationGroup.label = "Select Duration"

    let defaultSelected = false
    durations.forEach(d => {
      if (d.minutes >= minDuration && d.minutes <= maxDuration && d.minutes % minDuration === 0) {
        const option = document.createElement("option")
        option.value = d.minutes
        option.dataset.type = "duration"

        // Find matching end time display
        const matchingSlot = data.available_end_times.find(et => et.duration_minutes === d.minutes)
        option.textContent = `${d.label} (until ${matchingSlot ? matchingSlot.display : ""})`

        // Default to 1 hour if available, otherwise first option
        if (d.minutes === 60 && !defaultSelected) {
          option.selected = true
          defaultSelected = true
        }

        durationGroup.appendChild(option)
      }
    })

    // If no 1 hour option, select first available
    if (!defaultSelected && durationGroup.children.length > 0) {
      durationGroup.children[0].selected = true
    }

    this.endTimeSelectTarget.appendChild(durationGroup)

    // Create option group for specific end times
    const endTimeGroup = document.createElement("optgroup")
    endTimeGroup.label = "Or Select End Time"

    data.available_end_times.forEach(et => {
      if (et.duration_minutes < minDuration || et.duration_minutes % minDuration !== 0) return

      const option = document.createElement("option")
      option.value = et.end_time
      option.dataset.type = "end_time"
      option.dataset.durationMinutes = et.duration_minutes
      option.textContent = `${et.display} (${this.formatDuration(et.duration_minutes)})`
      endTimeGroup.appendChild(option)
    })

    this.endTimeSelectTarget.appendChild(endTimeGroup)

    // Update duration display
    this.updateDurationDisplay()
  }

  formatDuration(minutes) {
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60

    if (hours === 0) return `${mins} min`
    if (mins === 0) return `${hours} hr`
    return `${hours} hr ${mins} min`
  }

  updateDurationDisplay() {
    const selected = this.endTimeSelectTarget.selectedOptions[0]
    if (!selected) return

    let durationMinutes
    if (selected.dataset.type === "duration") {
      durationMinutes = parseInt(selected.value)
    } else {
      durationMinutes = parseInt(selected.dataset.durationMinutes)
    }

    const slots = durationMinutes / 15
    this.durationDisplayTarget.textContent = `${this.formatDuration(durationMinutes)} (${slots} shift${slots > 1 ? "s" : ""})`
  }

  selectionChanged() {
    this.updateDurationDisplay()
  }

  selectedDurationMinutes() {
    const selected = this.endTimeSelectTarget.selectedOptions[0]
    if (!selected) return null

    return selected.dataset.type === "duration"
      ? parseInt(selected.value)
      : parseInt(selected.dataset.durationMinutes)
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("d-none")
  }

  hideError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("d-none")
  }

  async submit(event) {
    event.preventDefault()
    this.hideError()

    const selected = this.endTimeSelectTarget.selectedOptions[0]
    if (!selected) return

    // Guard against a shift that isn't a whole number of blocks, in case such
    // an option is submitted anyway. The server also enforces this.
    const durationMinutes = this.selectedDurationMinutes()
    const block = this.minDuration || 15
    if (durationMinutes < block || durationMinutes % block !== 0) {
      this.showError(`Shifts must be booked in ${this.formatDuration(block)} blocks for this conference.`)
      return
    }

    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.textContent = "Signing up..."

    const formData = new FormData()
    formData.append("timeslot_id", this.timeslotIdValue)

    if (selected.dataset.type === "duration") {
      formData.append("duration_minutes", selected.value)
    } else {
      formData.append("end_time", selected.value)
    }

    try {
      const response = await fetch(this.bulkCreateUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: formData
      })

      // Follow redirect
      if (response.redirected) {
        window.location.href = response.url
      } else {
        window.location.reload()
      }
    } catch (error) {
      console.error("Error creating signup:", error)
      alert("Failed to sign up. Please try again.")
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.textContent = "Sign Up"
    }
  }

  closeModal() {
    this.modal.hide()
  }
}
