import { Controller } from "@hotwired/stimulus"

// Gap-scoped claiming on a coverage ribbon (#240).
//
// The server renders every tick (state, timeslot id, start time) and the gap
// runs as JSON; this controller only handles selection: tap an uncovered tick
// to set the claim start, offer block-snapped lengths that fit the rest of
// that hole (capped), and fill the hidden fields of the plain bulk_create
// form. No fetch — the form posts and the server re-renders the ribbon.
export default class extends Controller {
  static targets = ["ribbon", "claimPanel", "lengthOptions", "timeslotField", "durationField", "submitButton", "hint"]
  static values = {
    blockMinutes: Number,
    capMinutes: Number,
    gaps: Array,
    focusTimeslotId: Number
  }

  connect() {
    // Deep link from the triage "Cover" button (#241): pre-select that gap.
    if (this.focusTimeslotIdValue) {
      const tick = this.ribbonTarget.querySelector(`[data-timeslot-id='${this.focusTimeslotIdValue}']`)
      if (tick && (tick.classList.contains("bare") || tick.classList.contains("short"))) {
        this.armFrom(tick)
        this.element.scrollIntoView({ block: "center" })
      }
    }
    // Signal readiness so system tests can wait for the controller.
    this.element.dataset.coverageRibbonReady = "true"
  }

  pickStart(event) {
    this.armFrom(event.currentTarget)
  }

  armFrom(tick) {
    const startIso = tick.dataset.start
    const gap = this.gapsValue.find(g => g.start <= startIso && startIso < g.end)
    if (!gap) return

    this.startTick = tick
    this.timeslotFieldTarget.value = tick.dataset.timeslotId

    // Lengths that fit between the picked start and the end of this hole,
    // in whole blocks, capped (settled decision: 4h max per claim).
    const remaining = (new Date(gap.end) - new Date(startIso)) / 60000
    const max = Math.min(remaining, this.capMinutesValue)
    const options = []
    for (let m = this.blockMinutesValue; m <= max; m += this.blockMinutesValue) options.push(m)

    this.renderLengthOptions(options)
    this.selectLength(options.includes(60) ? 60 : options[options.length - 1])

    if (this.hasHintTarget) this.hintTarget.hidden = true
    this.claimPanelTarget.hidden = false
  }

  renderLengthOptions(options) {
    this.lengthOptionsTarget.innerHTML = ""
    options.forEach(minutes => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "btn btn-sm btn-outline-secondary"
      button.dataset.minutes = minutes
      button.textContent = this.formatDuration(minutes)
      button.addEventListener("click", () => this.selectLength(minutes))
      this.lengthOptionsTarget.appendChild(button)
    })
  }

  selectLength(minutes) {
    this.durationFieldTarget.value = minutes
    this.lengthOptionsTarget.querySelectorAll("button").forEach(button => {
      button.classList.toggle("active", Number(button.dataset.minutes) === minutes)
    })
    this.highlightSelection(minutes)

    const start = new Date(this.startTick.dataset.start)
    const end = new Date(start.getTime() + minutes * 60000)
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.textContent =
      `Cover ${this.startTick.dataset.label} – ${this.formatTime(end)}`
  }

  highlightSelection(minutes) {
    const startIso = this.startTick.dataset.start
    const endMs = new Date(startIso).getTime() + minutes * 60000
    this.ribbonTarget.querySelectorAll(".tick").forEach(tick => {
      const tickMs = new Date(tick.dataset.start).getTime()
      tick.classList.toggle("selected", tick.dataset.start >= startIso && tickMs < endMs)
    })
  }

  formatDuration(minutes) {
    const hours = Math.floor(minutes / 60)
    const mins = minutes % 60
    if (hours === 0) return `${mins}m`
    if (mins === 0) return `${hours}h`
    return `${hours}h ${mins}m`
  }

  formatTime(date) {
    return date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
  }
}
