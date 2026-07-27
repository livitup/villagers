import { Controller } from "@hotwired/stimulus"

// Submits the form it is attached to as soon as a wired control changes,
// so toggles apply without a separate "Apply" click. Attach to a form and
// add data-action="change->auto-submit#submit" to the controls that should
// apply immediately.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
