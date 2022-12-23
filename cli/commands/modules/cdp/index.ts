import yargs, { Argv } from 'yargs'
import { overviewCommand } from './read/overview'
import { addCollateralCommand } from './write/addCollateral'
import { addDebtCommand } from './write/addDebt'
import { closeCommand } from './write/close'
import { liquidateCommand } from './write/liquidate'
import { openCommand } from './write/open'
import { removeCollateralCommand } from './write/removeCollateral'
import { removeDebtCommand } from './write/removeDebt'

export const cdpCommand = {
  command: 'cdp',
  describe: 'Photon protocol modules',
  builder: (yargs: Argv): yargs.Argv => {
    return yargs
      .command(openCommand)
      .command(addCollateralCommand)
      .command(removeCollateralCommand)
      .command(addDebtCommand)
      .command(removeDebtCommand)
      .command(closeCommand)
      .command(liquidateCommand)
      .command(overviewCommand)
  },
  handler: (): void => {
    yargs.showHelp()
  }
}
