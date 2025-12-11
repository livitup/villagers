import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-capacity-update"
export default class extends Controller {
  static targets = ["maxVolunteers", "modal", "conferenceList", "selectAll", "submitBtn", "loading"]
  static values = {
    programId: Number,
    originalValue: Number,
    affectedConferencesUrl: String,
    bulkUpdateUrl: String
  }

  connect() {
    this.originalValueValue = parseInt(this.maxVolunteersTarget.value) || 1
  }

  async checkForChanges(event) {
    const newValue = parseInt(this.maxVolunteersTarget.value)

    // If value changed, check for affected conferences
    if (newValue !== this.originalValueValue && newValue > 0) {
      await this.loadAffectedConferences(newValue)
    }
  }

  async loadAffectedConferences(newMaxVolunteers) {
    try {
      const response = await fetch(`${this.affectedConferencesUrlValue}?new_max_volunteers=${newMaxVolunteers}`)
      const data = await response.json()

      if (data.conferences && data.conferences.length > 0) {
        this.renderConferenceList(data.conferences, newMaxVolunteers)
        this.showModal()
      }
    } catch (error) {
      console.error("Error loading affected conferences:", error)
    }
  }

  renderConferenceList(conferences, newMaxVolunteers) {
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
                  Current: ${conf.current_max_volunteers} volunteers/shift |
                  ${conf.timeslots_count} timeslots
                </small>
              </div>
              <div class="text-end">
                <span class="badge bg-primary">${conf.current_max_volunteers} → ${newMaxVolunteers}</span>
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
          new_max_volunteers: newMaxVolunteers,
          conference_program_ids: conferenceProgrmIds
        })
      })

      const data = await response.json()
      if (data.success) {
        this.hideModal()
        // Update original value to prevent modal showing again
        this.originalValueValue = newMaxVolunteers
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
    // Update original value to prevent modal showing again on re-save
    this.originalValueValue = parseInt(this.maxVolunteersTarget.value)
  }
}
