const team = { type: 'integer', enum: [0, 1] };
export const snapshotBody = {
 type: 'object', additionalProperties: false,
 required: ['user','clientGameId','clientSnapshotId','dealNumber','moveNumber','dealStatus','savedAt','appVersion','botStrategy','snapshot'],
 properties: {
  user: {type:'object', additionalProperties:false, required:['email','googleSubject'], properties:{email:{type:'string',maxLength:254},googleSubject:{type:'string',maxLength:255}}},
  clientGameId:{type:'string',minLength:1,maxLength:128},
  clientSnapshotId:{type:'string',format:'uuid'},
  dealNumber:{type:'integer',minimum:1,maximum:100000},
  moveNumber:{type:'integer',minimum:0,maximum:48},
  dealStatus:{type:'string',enum:['in_progress','completed']},
  savedAt:{type:'string',format:'date-time'},
  appVersion:{type:'string',minLength:1,maxLength:64},
  botStrategy:{type:'string',minLength:1,maxLength:64},
  snapshot:{type:'object',required:['deal','state','decisions'],properties:{deal:{type:'object'},state:{type:'object'},decisions:{type:'array'}},additionalProperties:true}
 }
};
const total = { type: 'integer', minimum: 0, maximum: 2147483647 };
export const reportBody = {
  type: 'object', additionalProperties: false,
  required: ['user', 'clientGameId', 'dealCount', 'winnerTeam', 'team0Total', 'team1Total'],
  properties: {
    user: {
      type: 'object', additionalProperties: false, required: ['email'],
      properties: {
        email: { type: 'string', minLength: 3, maxLength: 254, pattern: '^\\s*[^\\s@]+@[^\\s@]+\\.[^\\s@]+\\s*$' },
        displayName: { type: ['string', 'null'], maxLength: 100 },
        googleSubject: { type: 'string', minLength: 1, maxLength: 255 },
      },
    },
    clientGameId: { type: 'string', minLength: 1, maxLength: 128, pattern: '^\\S+$' },
    appVersion: { type: ['string', 'null'], maxLength: 64 },
    platform: { type: ['string', 'null'], maxLength: 32 },
    dealCount: { type: 'integer', minimum: 1, maximum: 100000 },
    humanTeam: { ...team, default: 0 },
    winnerTeam: team,
    userWon: { type: 'boolean' },
    team0Total: total, team1Total: total,
    summary: { type: 'object', default: {}, additionalProperties: true },
    gameLog: { type: ['object', 'null'], additionalProperties: true },
  },
};
export const userParams = {
  type: 'object', required: ['id'], properties: { id: { type: 'string', format: 'uuid' } },
};
export const reportsQuery = {
  type: 'object', additionalProperties: false,
  properties: {
    limit: { type: 'string', pattern: '^[1-9][0-9]{0,2}$' },
    offset: { type: 'string', pattern: '^[0-9]{1,7}$', default: '0' },
    includeGameLog: { type: 'string', enum: ['true', 'false'], default: 'false' },
  },
};
export const statsQuery = {
  type: 'object', additionalProperties: false,
  properties: {
    limit: { type: 'string', pattern: '^[1-9][0-9]{0,2}$', default: '10' },
    minGames: { type: 'string', pattern: '^[1-9][0-9]{0,4}$', default: '1' },
  },
};
