import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Bootstrap tooltips are opt-in — a `data-bs-toggle="tooltip"` attribute does
// nothing on its own. Attach data-controller="tooltip" to any element (or a
// container) and this initializes every tooltip trigger within it on connect,
// disposing them on disconnect so Turbo navigations don't leak instances.
export default class extends Controller {
  connect() {
    this._tooltips = Array.from(
      this.element.querySelectorAll('[data-bs-toggle="tooltip"]')
    ).map(el => new bootstrap.Tooltip(el))
  }

  disconnect() {
    this._tooltips?.forEach(t => t.dispose())
    this._tooltips = null
  }
}
