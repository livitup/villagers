import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-capacity-update"
export default class extends Controller {
  static targets = ["minVolunteers", "maxVolunteers", "modal", "conferenceList", "selectAll", "submitBtn", "loading"]
  static values = {
    programId: Number,
    originalValue: Number,
    originalMinValue: Number,
    affectedConferencesUrl: String,
    bulkUpdateUrl: String
  }

  connect() {
    this.originalValueValue = parseInt(this.maxVolunteersTarget.value) || 1
    this.originalMinValueValue = this.currentMin()
  }

  currentMin() {
    return this.hasMinVolunteersTarget ? (parseInt(this.minVolunteersTarget.value) || 1) : 1
  }

  async checkForChanges(event) {
    const newMax = parseInt(this.maxVolunteersTarget.value)
    const newMin = this.currentMin()
    const changed = newMax !== this.originalValueValue || newMin !== this.originalMinValueValue

    if (changed && newMax > 0 && newMin > 0 && newMin <= newMax) {
      await this.loadAffectedConferences(newMin, newMax)
    }
  }

  async loadAffectedConferences(newMinVolunteers, newMaxVolunteers) {
    try {
      const response = await fetch(`${this.affectedConferencesUrlValue}?new_max_volunteers=${newMaxVolunteers}`)
      const data = await response.json()

      if (data.conferences && data.conferences.length > 0) {
        this.renderConferenceList(data.conferences, newMinVolunteers, newMaxVolunteers)
        this.showModal()
      }
    } catch (error) {
      console.error("Error loading affected conferences:", error)
    }
  }

  renderConferenceList(conferences, newMinVolunteers, newMaxVolunteers) {
    let html = ""
    conferences.forEach(conf => {
      const warningBadge = conf.over_capacity_count > 0
        ? `<span class="badge bg-warning text-dark ms-2">${conf.over_capacity_count} over capacity</span>`
        : ""
      const overrideBadge = conf.has_override
        ? `<span class="badge bg-secondary ms-2">Has override</span>`
        : ""

      html += `
        <div class="form-check mb-2 p-3 border rounded">
          <input class="form-check-input conference-checkbox" type="checkbox"
                 value="${conf.conference_program_id}" id="conf_${conf.conference_program_id}"
                 ${conf.has_override ? "" : "checked"}>
          <label class="form-check-label w-100" for="conf_${conf.conference_program_id}">
            <div class="d-flex justify-content-between align-items-start">
              <div>
                <strong>${conf.conference_name}</strong>
                ${overrideBadge}
                ${warningBadge}
                <br>
                <small class="text-muted">
                  Current: ${conf.current_min_volunteers}–${conf.current_max_volunteers} volunteers/shift |
                  ${conf.timeslots_count} timeslots
                </small>
              </div>
              <div class="text-end">
                <span class="badge bg-primary">${conf.current_min_volunteers}–${conf.current_max_volunteers} → ${newMinVolunteers}–${newMaxVolunteers}</span>
              </div>
            </div>
          </label>
        </div>
      `
    })
    this.conferenceListTarget.innerHTML = html
  }

  showModal() {
    this.modalTarget.classList.add("show")
    this.modalTarget.style.display = "block"
    document.body.classList.add("modal-open")
  }

  hideModal() {
    this.modalTarget.classList.remove("show")
    this.modalTarget.style.display = "none"
    document.body.classList.remove("modal-open")
  }

  toggleSelectAll() {
    const checkboxes = this.conferenceListTarget.querySelectorAll(".conference-checkbox")
    const allChecked = this.selectAllTarget.checked
    checkboxes.forEach(cb => cb.checked = allChecked)
  }

  async submitBulkUpdate() {
    const checkboxes = this.conferenceListTarget.querySelectorAll(".conference-checkbox:checked")
    const conferenceProgrmIds = Array.from(checkboxes).map(cb => cb.value)
    const newMaxVolunteers = parseInt(this.maxVolunteersTarget.value)
    const newMinVolunteers = this.currentMin()

    if (conferenceProgrmIds.length === 0) {
      this.hideModal()
      return
    }

    this.submitBtnTarget.disabled = true
    this.loadingTarget.classList.remove("d-none")

    try {
      const response = await fetch(this.bulkUpdateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          new_min_volunteers: newMinVolunteers,
          new_max_volunteers: newMaxVolunteers,
          conference_program_ids: conferenceProgrmIds
        })
      })

      const data = await response.json()
      if (data.success) {
        this.hideModal()
        // Update original values to prevent modal showing again
        this.originalValueValue = newMaxVolunteers
        this.originalMinValueValue = newMinVolunteers
      }
    } catch (error) {
      console.error("Error updating capacity:", error)
    } finally {
      this.submitBtnTarget.disabled = false
      this.loadingTarget.classList.add("d-none")
    }
  }

  skipUpdate() {
    this.hideModal()
    // Update original values to prevent modal showing again on re-save
    this.originalValueValue = parseInt(this.maxVolunteersTarget.value)
    this.originalMinValueValue = this.currentMin()
  }
}
