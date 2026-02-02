/**
 * Internal proc to handle most all of the signaling procedure
 *
 * Will runtime if used on datums with an empty lookup list
 *
 * Use the [SEND_SIGNAL] define instead
 */
/datum/proc/_SendSignal(sigtype, list/arguments)
	var/target = _listen_lookup[sigtype]
	if(!length(target))
		var/datum/listening_datum = target
		return NONE | call(listening_datum, listening_datum._signal_procs[src][sigtype])(arglist(arguments))
	. = NONE
	// This exists so that even if one of the signal receivers unregisters the signal,
	// all the objects that are receiving the signal get the signal this final time.
	// AKA: No you can't cancel the signal reception of another object by doing an unregister in the same signal.
	var/list/queued_calls = list()
	// This should be faster than doing `var/datum/listening_datum as anything in target` as it does not implicitly copy the list
	for(var/i in 1 to length(target))
		var/datum/listening_datum = target[i]
		queued_calls.Add(listening_datum, listening_datum._signal_procs[src][sigtype])
	for(var/i in 1 to length(queued_calls) step 2)
		. |= call(queued_calls[i], queued_calls[i + 1])(arglist(arguments))
