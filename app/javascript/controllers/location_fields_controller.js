import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="location-fields"
export default class extends Controller {
  static targets = ["country", "state", "stateContainer"]
  static values = { statesUrl: String }

  connect() {
    this.loadStates()
  }

  countryChanged() {
    this.loadStates()
  }

  async loadStates() {
    const country = this.countryTarget.value
    if (!country) {
      this.hideStateField()
      return
    }

    try {
      const response = await fetch(`${this.statesUrlValue}?country=${country}`)
      const states = await response.json()

      if (states.length > 0) {
        this.populateStates(states)
        this.showStateField()
      } else {
        this.hideStateField()
      }
    } catch (error) {
      console.error("Error loading states:", error)
      this.hideStateField()
    }
  }

  populateStates(states) {
    const currentValue = this.stateTarget.value
    this.stateTarget.innerHTML = '<option value="">Select state/province...</option>'

    states.forEach(state => {
      const option = document.createElement("option")
      option.value = state.code
      option.textContent = state.name
      if (state.code === currentValue) {
        option.selected = true
      }
      this.stateTarget.appendChild(option)
    })
  }

  showStateField() {
    this.stateContainerTarget.style.display = "block"
  }

  hideStateField() {
    this.stateContainerTarget.style.display = "none"
    this.stateTarget.value = ""
  }
}
