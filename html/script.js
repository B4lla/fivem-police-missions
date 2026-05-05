const app = document.getElementById('app');
const missionIssuer = document.getElementById('missionIssuer');
const missionTitle = document.getElementById('missionTitle');
const missionBriefing = document.getElementById('missionBriefing');
const missionDifficulty = document.getElementById('missionDifficulty');
const missionReward = document.getElementById('missionReward');
const jobTag = document.getElementById('jobTag');
const teamCapacity = document.getElementById('teamCapacity');
const teamMembersList = document.getElementById('teamMembers');
const nearbyPlayersList = document.getElementById('nearbyPlayers');

const acceptBtn = document.getElementById('acceptBtn');
const rejectBtn = document.getElementById('rejectBtn');

const invitePopup = document.getElementById('invitePopup');
const inviteLeader = document.getElementById('inviteLeader');
const inviteMission = document.getElementById('inviteMission');
const inviteAccept = document.getElementById('inviteAccept');
const inviteDecline = document.getElementById('inviteDecline');

let writingTimer = null;
let currentInviteId = null;
let maxMembers = 4;

function postNui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
}

function typeWriter(text) {
    missionBriefing.textContent = '';

    if (writingTimer) {
        clearInterval(writingTimer);
        writingTimer = null;
    }

    let index = 0;
    writingTimer = setInterval(() => {
        if (index < text.length) {
            missionBriefing.textContent += text.charAt(index);
            index += 1;
        } else {
            clearInterval(writingTimer);
            writingTimer = null;
        }
    }, 30);
}

function renderMembers(members) {
    teamMembersList.innerHTML = '';

    if (!Array.isArray(members) || members.length === 0) {
        teamMembersList.innerHTML = '<li class="empty-item">Sin miembros.</li>';
        teamCapacity.textContent = `0/${maxMembers}`;
        return;
    }

    teamCapacity.textContent = `${members.length}/${maxMembers}`;

    members.forEach((member, index) => {
        const li = document.createElement('li');
        li.className = 'list-item';

        const nameSpan = document.createElement('span');
        nameSpan.textContent = member.name || `ID ${member.id}`;
        li.appendChild(nameSpan);

        if (index === 0) {
            const selfTag = document.createElement('span');
            selfTag.className = 'tag-self';
            selfTag.textContent = 'LIDER';
            li.appendChild(selfTag);
        }

        teamMembersList.appendChild(li);
    });
}

function renderNearby(nearby) {
    nearbyPlayersList.innerHTML = '';

    if (!Array.isArray(nearby) || nearby.length === 0) {
        nearbyPlayersList.innerHTML = '<li class="empty-item">No hay jugadores cerca.</li>';
        return;
    }

    nearby.forEach((player) => {
        const li = document.createElement('li');
        li.className = 'list-item';

        const nameSpan = document.createElement('span');
        nameSpan.textContent = player.name || `ID ${player.id}`;
        li.appendChild(nameSpan);

        const btn = document.createElement('button');
        btn.className = 'invite-btn';
        btn.type = 'button';
        btn.dataset.serverId = String(player.id);
        btn.textContent = 'Invitar';
        li.appendChild(btn);

        nearbyPlayersList.appendChild(li);
    });
}

function openUi(payload) {
    app.classList.remove('hidden');

    missionIssuer.textContent = payload.issuer || 'Central';
    missionTitle.textContent = payload.title || 'Asignacion';
    missionDifficulty.textContent = (payload.difficulty || 'normal').toUpperCase();
    missionReward.textContent = `$${payload.cashMin || 120} - $${payload.cashMax || 250} (EFECTIVO)`;

    maxMembers = Number(payload.maxMembers || 4);

    if (payload.job === 'police') {
        jobTag.textContent = 'LSPD SERVICE';
    } else if (payload.job === 'ambulance') {
        jobTag.textContent = 'EMS SERVICE';
    } else {
        jobTag.textContent = 'SERVICE';
    }

    renderMembers(payload.members || []);
    renderNearby(payload.nearby || []);
    typeWriter(payload.briefing || '');
}

function closeUi(notify = true) {
    app.classList.add('hidden');

    if (writingTimer) {
        clearInterval(writingTimer);
        writingTimer = null;
    }

    if (notify) {
        postNui('closeUi');
    }
}

function openInvitePopup(payload) {
    currentInviteId = payload.inviteId;
    inviteLeader.textContent = payload.leaderName || 'Lider de servicio';
    inviteMission.textContent = payload.missionTitle || 'Mision de servicio';
    invitePopup.classList.remove('hidden');
}

function closeInvitePopup() {
    currentInviteId = null;
    invitePopup.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) {
        return;
    }

    if (data.action === 'open') {
        openUi(data.payload || {});
        return;
    }

    if (data.action === 'updateLobby') {
        const payload = data.payload || {};
        maxMembers = Number(payload.maxMembers || maxMembers || 4);
        renderMembers(payload.members || []);
        renderNearby(payload.nearby || []);
        return;
    }

    if (data.action === 'incomingInvite') {
        openInvitePopup(data.payload || {});
        return;
    }

    if (data.action === 'closeInvite') {
        closeInvitePopup();
        return;
    }

    if (data.action === 'close') {
        closeUi(false);
    }
});

nearbyPlayersList.addEventListener('click', (event) => {
    const button = event.target.closest('.invite-btn');
    if (!button) {
        return;
    }

    const serverId = Number(button.dataset.serverId);
    if (!Number.isInteger(serverId)) {
        return;
    }

    postNui('invitePlayer', { serverId });
    button.disabled = true;
    button.textContent = 'Enviada';
});

acceptBtn.addEventListener('click', () => {
    postNui('acceptMission').then(() => {
        closeUi(false);
    });
});

rejectBtn.addEventListener('click', () => {
    postNui('rejectMission').then(() => {
        closeUi(false);
    });
});

inviteAccept.addEventListener('click', () => {
    if (!currentInviteId) {
        return;
    }

    postNui('acceptInvite', { inviteId: currentInviteId }).then(() => {
        closeInvitePopup();
    });
});

inviteDecline.addEventListener('click', () => {
    if (!currentInviteId) {
        return;
    }

    postNui('declineInvite', { inviteId: currentInviteId }).then(() => {
        closeInvitePopup();
    });
});

window.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') {
        return;
    }

    if (!invitePopup.classList.contains('hidden')) {
        closeInvitePopup();
        return;
    }

    if (!app.classList.contains('hidden')) {
        closeUi(true);
    }
});
