import winston, { format } from 'winston'

export const logger: winston.Logger = winston.createLogger({
  level: 'info',
  format: format.combine(
    format.colorize(),
    format.printf(({ message }) => `${message as string}`)
  ),
  transports: [new winston.transports.Console({ level: 'info' })]
})
