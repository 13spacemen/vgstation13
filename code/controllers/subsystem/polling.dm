var/datum/subsystem/polling/SSpolling

/datum/subsystem/polling
	name = "Polling"
	flags = SS_BACKGROUND | SS_NO_INIT
	wait = 1 SECONDS
	/// List of polls currently ongoing, to be checked on next fire()
	var/list/datum/candidate_poll/currently_polling
	/// Number of polls performed since the start
	var/total_polls = 0

/datum/subsystem/polling/New()
	NEW_SS_GLOBAL(SSpolling)

/datum/subsystem/polling/fire()
	if(!currently_polling) // if polls_active is TRUE then this shouldn't happen, but still..
		currently_polling = list()

	for(var/datum/candidate_poll/running_poll as anything in currently_polling)
		if(running_poll.time_left() <= 0)
			polling_finished(running_poll)

/datum/subsystem/polling/proc/poll_candidates(question, role, check_jobban, poll_time = 30 SECONDS, flash_window = TRUE, list/group = null, pic_source, role_name_text)
	if(group.len == 0)
		return list()
	if(role && !role_name_text)
		role_name_text = role
	if(role_name_text && !question)
		question = "Do you want to play as [full_capitalize(role_name_text)]?"
	if(!question)
		question = "Do you want to play as a special role?"
	log_game("Polling candidates [role_name_text ? "for [role_name_text]" : "\"[question]\""] for [DisplayTimeText(poll_time)] seconds")

	// Start firing
	total_polls++

	var/jumpable = isatom(pic_source) ? pic_source : null

	var/datum/candidate_poll/new_poll = new(role_name_text, question, poll_time, jumpable)
	currently_polling += new_poll

	var/category = "[new_poll.poll_key]_poll_alert"

	for(var/mob/candidate_mob as anything in group)
		if(!candidate_mob.client)
			continue
		if(!is_eligible(candidate_mob, role, check_jobban))
			continue

		SEND_SOUND(candidate_mob, 'sound/misc/notice2.ogg')
		if(flash_window)
			window_flash(candidate_mob.client)

		// If we somehow send two polls for the same mob type, but with a duration on the second one shorter than the time left on the first one,
		// we need to keep the first one's timeout rather than use the shorter one
		var/obj/abstract/screen/alert/poll_alert/current_alert = candidate_mob.alerts[category]
		var/alert_time = poll_time
		var/datum/candidate_poll/alert_poll = new_poll
		if(current_alert && current_alert.timeout > (world.time + poll_time - world.tick_lag))
			alert_time = current_alert.timeout - world.time + world.tick_lag
			alert_poll = current_alert.poll

		// Send them an on-screen alert
		var/obj/abstract/screen/alert/poll_alert/poll_alert_button = candidate_mob.throw_alert(category, /obj/abstract/screen/alert/poll_alert, timeout_override = alert_time, no_anim = TRUE)
		if(!poll_alert_button)
			continue

		new_poll.alert_buttons += poll_alert_button

		poll_alert_button.icon = ui_style2icon(candidate_mob.client?.prefs?.UI_style)
		poll_alert_button.desc = "[question]"
		poll_alert_button.show_time_left = TRUE
		poll_alert_button.poll = alert_poll
		poll_alert_button.set_role_overlay()
		poll_alert_button.update_stacks_overlay()


		// Sign up inheritance and stacking
		for(var/datum/candidate_poll/other_poll as anything in currently_polling)
			if(new_poll == other_poll || new_poll.poll_key != other_poll.poll_key)
				continue
			// If there's already a poll for an identical mob type ongoing and the client is signed up for it, sign them up for this one
			if((candidate_mob in other_poll.signed_up) && new_poll.sign_up(candidate_mob, TRUE))
				break

		// Image to display
		var/image/poll_image
		if(pic_source)
			if(!ispath(pic_source))
				var/atom/the_pic_source = pic_source
				var/old_layer = the_pic_source.layer
				var/old_plane = the_pic_source.plane
				the_pic_source.layer = FLOAT_LAYER
				the_pic_source.plane = FLOAT_PLANE
				poll_alert_button.overlays += the_pic_source
				the_pic_source.layer = old_layer
				the_pic_source.plane = old_plane
			else
				poll_image = image(pic_source, layer = FLOAT_LAYER)
		else
			// Just use a generic image
			poll_image = image('icons/effects/effects.dmi', icon_state = "static", layer = FLOAT_LAYER)

		if(poll_image)
			poll_image.layer = FLOAT_LAYER
			poll_image.plane = FLOAT_PLANE
			poll_alert_button.overlays += poll_image

		// Chat message
		var/act_jump = ""
		if(isatom(pic_source) && isobserver(candidate_mob))
			act_jump = "<a href='?src=\ref[poll_alert_button];jump=1'>\[Teleport]</a>"
		var/act_signup = "<a href='?src=\ref[poll_alert_button];signup=1'>\[Sign Up]</a>"
		var/act_never = "<a href='?src=\ref[poll_alert_button];never=1'>\[Never For This Round]</a>"
		to_chat(candidate_mob, span_boldnotice("<big>Now looking for candidates [role_name_text ? "to play as \an [role_name_text]." : "\"[question]\""] [act_jump] [act_signup] [act_never]</big>"))

		// Start processing it so it updates visually the timer
		processing_objects += poll_alert_button

	// Sleep until the time is up
	UNTIL(new_poll.finished)
	return new_poll.signed_up

/datum/subsystem/polling/proc/poll_ghost_candidates(question, role, check_jobban, poll_time = 30 SECONDS, flashwindow = TRUE, pic_source, role_name_text)
	var/list/candidates = list()

	for(var/mob/dead/observer/ghost_player in player_list)
		candidates += ghost_player

	return poll_candidates(question, role, check_jobban, poll_time, flashwindow, candidates, pic_source, role_name_text)

/datum/subsystem/polling/proc/poll_ghost_candidates_for_mob(question, role, check_jobban, poll_time = 30 SECONDS, mob/target_mob, flashwindow = TRUE, pic_source, role_name_text)
	var/static/list/mob/currently_polling_mobs = list()

	if(currently_polling_mobs.Find(target_mob))
		return list()

	currently_polling_mobs += target_mob

	var/list/possible_candidates = poll_ghost_candidates(question, role, check_jobban, poll_time, flashwindow, pic_source, role_name_text)

	currently_polling_mobs -= target_mob
	if(!target_mob || QDELETED(target_mob) || !target_mob.loc)
		return list()

	return possible_candidates

/datum/subsystem/polling/proc/poll_ghost_candidates_for_mobs(question, role, check_jobban, poll_time = 30 SECONDS, list/mobs, flashwindow = TRUE, pic_source, role_name_text)
	var/list/candidate_list = poll_ghost_candidates(question, role, check_jobban, poll_time, flashwindow, pic_source, role_name_text)

	for(var/mob/potential_mob as anything in mobs)
		if(QDELETED(potential_mob) || !potential_mob.loc)
			mobs -= potential_mob

	if(!length(mobs))
		return list()

	return candidate_list

/datum/subsystem/polling/proc/is_eligible(mob/potential_candidate, role, check_jobban)
	if(isnull(potential_candidate.key) || isnull(potential_candidate.client))
		return FALSE
	if(role)
		if(!(potential_candidate.client.desires_role(role)))
			return FALSE
	if(check_jobban)
		if(jobban_isbanned(potential_candidate, check_jobban))
			return FALSE
		if(isantagbanned(potential_candidate))
			return FALSE
	return TRUE

/datum/subsystem/polling/proc/polling_finished(datum/candidate_poll/finishing_poll)
	currently_polling -= finishing_poll
	// Trim players who aren't eligible anymore
	var/length_pre_trim = length(finishing_poll.signed_up)
	finishing_poll.trim_candidates()
	log_game("Candidate poll [finishing_poll.role ? "for [finishing_poll.role]" : "\"[finishing_poll.question]\""] finished. [length_pre_trim] players signed up, [length(finishing_poll.signed_up)] after trimming")
	finishing_poll.finished = TRUE

	// Take care of updating the remaining screen alerts if a similar poll is found, or deleting them.
	if(length(finishing_poll.alert_buttons))
		var/polls_of_same_type_left = FALSE
		for(var/datum/candidate_poll/running_poll as anything in currently_polling)
			if(running_poll.poll_key == finishing_poll.poll_key && running_poll.time_left() > 0)
				polls_of_same_type_left = TRUE
				break
		for(var/obj/abstract/screen/alert/poll_alert/alert as anything in finishing_poll.alert_buttons)
			if(polls_of_same_type_left)
				alert.update_stacks_overlay()
			else
				alert.owner.clear_alert("[finishing_poll.poll_key]_poll_alert")

	//More than enough time for the the `UNTIL()` stopping loop in `poll_candidates()` to be over, and the results to be turned in.
	spawn(0.5 SECONDS)
		qdel(finishing_poll)

/datum/subsystem/polling/stat_entry(msg)
	msg += "Active: [length(currently_polling)] | Total: [total_polls]"
	var/datum/candidate_poll/soonest_to_complete = get_next_poll_to_finish()
	if(soonest_to_complete)
		msg += " | Next: [DisplayTimeText(soonest_to_complete.time_left())] ([length(soonest_to_complete.signed_up)] candidates)"
	return ..()

/datum/subsystem/polling/proc/get_next_poll_to_finish()
	var/lowest_time_left = INFINITY
	var/next_poll_to_finish
	for(var/datum/candidate_poll/poll as anything in currently_polling)
		var/time_left = poll.time_left()
		if(time_left >= lowest_time_left)
			continue
		lowest_time_left = time_left
		next_poll_to_finish = poll

	if(isnull(next_poll_to_finish))
		return FALSE

	return next_poll_to_finish
