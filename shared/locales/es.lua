local Translations = {
    error = {
        job_not_allowed = 'No perteneces al cuerpo requerido para esta terminal.',
        already_on_mission = 'Ya tienes una mision activa.',
        cooldown = 'Debes esperar %{seconds}s antes de tomar otra mision.',
        mission_failed = 'La mision se ha cancelado o fallado.',
        no_mission_found = 'No hay misiones disponibles ahora mismo.',
        invite_limit = 'Has alcanzado el limite maximo de equipo.',
        invite_only_near = 'Solo puedes invitar jugadores cercanos y del mismo cuerpo.',
        no_payout_activity = 'Sin pago: no hubo participacion suficiente en checkpoints.',
        no_payout_distance = 'Sin pago: estabas demasiado lejos del lider al finalizar.'
    },
    success = {
        mission_started = 'Mision iniciada. Revisa tu GPS y sigue el protocolo.',
        mission_completed = 'Mision completada. Pago recibido: $%{amount} en efectivo.',
        invited_player = 'Invitacion enviada a %{name}.',
        invite_accepted = '%{name} se ha unido al equipo.',
        team_started = 'Mision en equipo iniciada (%{count} miembros).'
    },
    info = {
        mission_rejected = 'Has rechazado la mision.',
        open_tablet = 'Abriendo terminal de servicio...',
        stage_done = 'Etapa completada.',
        cancel_tip = 'Escribe /cancelservicio para abandonar la mision activa.',
        mission_title = 'Nueva asignacion disponible',
        invite_received = 'Has recibido una invitacion de %{leader}.',
        invite_declined = 'Has rechazado la invitacion.',
        invite_window = 'Esperando respuestas de invitacion...'
    }
}

---@diagnostic disable-next-line: undefined-global
Lang = Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
