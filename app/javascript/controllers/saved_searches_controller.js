import { Controller } from "@hotwired/stimulus"

const FILTER_KEYS = new Set([
  "q",
  "project_id",
  "organization",
  "category",
  "updated_since",
  "assignee_status",
  "sort",
  "starter_mode",
  "labels[]",
  "group_by_project",
])

export default class extends Controller {
  static targets = [ "form", "name", "list", "empty", "feedback" ]
  static values = {
    storageKey: String,
    path: String,
    pristine: Boolean,
    limit: { type: Number, default: 10 },
    applyLabel: String,
    defaultLabel: String,
    removeDefaultLabel: String,
    deleteLabel: String,
    defaultBadge: String,
    nameRequired: String,
    savedMessage: String,
    updatedMessage: String,
    limitMessage: String,
    storageError: String,
  }

  connect() {
    this.render()
    this.applyDefaultSearch()
  }

  save(event) {
    if (event.type === "keydown" && event.key !== "Enter") return

    event.preventDefault()
    const name = this.nameTarget.value.trim()
    if (!name) {
      this.showFeedback(this.nameRequiredValue, true)
      this.nameTarget.focus()
      return
    }

    const state = this.loadState()
    const existing = state.searches.find((search) => search.name.toLowerCase() === name.toLowerCase())
    if (!existing && state.searches.length >= this.limitValue) {
      this.showFeedback(this.limitMessageValue, true)
      return
    }

    if (existing) {
      existing.name = name
      existing.query = this.currentQuery()
    } else {
      state.searches.push({ id: `${Date.now()}-${Math.random()}`, name, query: this.currentQuery() })
    }

    if (!this.storeState(state)) return

    this.nameTarget.value = ""
    this.showFeedback(existing ? this.updatedMessageValue : this.savedMessageValue)
    this.render()
  }

  apply(event) {
    const search = this.findSearch(event.currentTarget.dataset.searchId)
    if (search) this.visit(search.query)
  }

  toggleDefault(event) {
    const state = this.loadState()
    const searchId = event.currentTarget.dataset.searchId
    state.defaultId = state.defaultId === searchId ? null : searchId
    if (this.storeState(state)) this.render()
  }

  remove(event) {
    const state = this.loadState()
    const searchId = event.currentTarget.dataset.searchId
    state.searches = state.searches.filter((search) => search.id !== searchId)
    if (state.defaultId === searchId) state.defaultId = null
    if (this.storeState(state)) this.render()
  }

  applyDefaultSearch() {
    if (!this.pristineValue) return

    const state = this.loadState()
    const search = state.searches.find((item) => item.id === state.defaultId)
    if (search && search.query) this.visit(search.query)
  }

  render() {
    const state = this.loadState()
    this.listTarget.replaceChildren(...state.searches.map((search) => this.searchItem(search, state.defaultId)))
    this.emptyTarget.hidden = state.searches.length > 0
  }

  searchItem(search, defaultId) {
    const item = document.createElement("li")
    item.className = "flex flex-wrap items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 dark:border-slate-700 dark:bg-slate-900"

    const name = document.createElement("span")
    name.className = "mr-auto text-sm font-medium text-slate-800 dark:text-slate-100"
    name.textContent = search.name
    item.append(name)

    if (search.id === defaultId) {
      const badge = document.createElement("span")
      badge.className = "rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300"
      badge.textContent = this.defaultBadgeValue
      item.append(badge)
    }

    item.append(
      this.actionButton(this.applyLabelValue, "apply", search.id),
      this.actionButton(search.id === defaultId ? this.removeDefaultLabelValue : this.defaultLabelValue, "toggleDefault", search.id),
      this.actionButton(this.deleteLabelValue, "remove", search.id, true),
    )
    return item
  }

  actionButton(label, action, searchId, destructive = false) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = destructive ? "cursor-pointer text-xs font-medium text-rose-600 hover:text-rose-700 dark:text-rose-400" : "cursor-pointer text-xs font-medium text-indigo-600 hover:text-indigo-700 dark:text-indigo-400"
    button.textContent = label
    button.dataset.searchId = searchId
    button.dataset.action = `saved-searches#${action}`
    return button
  }

  currentQuery() {
    const params = new URLSearchParams()
    for (const [ key, value ] of new FormData(this.formTarget)) {
      if (FILTER_KEYS.has(key) && value.toString().trim()) params.append(key, value)
    }
    return params.toString()
  }

  findSearch(searchId) {
    return this.loadState().searches.find((search) => search.id === searchId)
  }

  visit(query) {
    const normalizedQuery = this.normalizeQuery(query)
    window.location.assign(`${this.pathValue}${normalizedQuery ? `?${normalizedQuery}` : ""}`)
  }

  normalizeQuery(query) {
    const normalized = new URLSearchParams()
    for (const [ key, value ] of new URLSearchParams(query)) {
      if (FILTER_KEYS.has(key) && value.trim()) normalized.append(key, value)
    }
    return normalized.toString()
  }

  loadState() {
    try {
      const parsed = JSON.parse(localStorage.getItem(this.storageKeyValue))
      const searches = Array.isArray(parsed?.searches) ? parsed.searches.filter((search) => (
        typeof search?.id === "string" && typeof search?.name === "string" && typeof search?.query === "string"
      )).slice(0, this.limitValue) : []
      const defaultId = searches.some((search) => search.id === parsed?.defaultId) ? parsed.defaultId : null
      return { searches, defaultId }
    } catch {
      return { searches: [], defaultId: null }
    }
  }

  storeState(state) {
    try {
      localStorage.setItem(this.storageKeyValue, JSON.stringify(state))
      return true
    } catch {
      this.showFeedback(this.storageErrorValue, true)
      return false
    }
  }

  showFeedback(message, error = false) {
    this.feedbackTarget.textContent = message
    this.feedbackTarget.classList.toggle("text-rose-600", error)
    this.feedbackTarget.classList.toggle("dark:text-rose-400", error)
  }
}
