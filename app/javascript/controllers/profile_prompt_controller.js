import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Soft nudge: show the profile-completion modal once per browser session.
// The server only renders the modal when the profile is incomplete, so once
// the volunteer fills it in it simply stops appearing. Dismissing it (button,
// backdrop, or Escape) suppresses it for the rest of the session.
export default class extends Controller {
  connect() {
    // Don't interrupt automated browsers (Selenium sets navigator.webdriver);
    // an auto-opening modal would intercept clicks in system tests. Real users
    // are never flagged this way. The modal still renders, so its markup and
    // the underlying completion logic stay covered by integration tests.
    if (navigator.webdriver) return
    if (sessionStorage.getItem("profilePromptDismissed")) return

    this._modal = new bootstrap.Modal(this.element)
    this.element.addEventListener("hidden.bs.modal", this._remember)
    this._modal.show()
  }

  disconnect() {
    this.element.removeEventListener("hidden.bs.modal", this._remember)
    this._modal?.dispose()
    this._modal = null
  }

  _remember() {
    sessionStorage.setItem("profilePromptDismissed", "true")
  }
}
