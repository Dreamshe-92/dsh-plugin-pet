/**
 * dsh-plugin-pet, node half. Pure UI plugin: the empty apply exists so the
 * plugin appears in the host cordis tree / Loader; the browser half ships via
 * exports["./client"], discovered through the package.json dsh.client
 * declaration.
 */
/** Host plugin body — no host-side behavior for this source plugin. */
export function apply() {}
