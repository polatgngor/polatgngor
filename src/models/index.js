// Sequelize instance and models registration (updated to include all models)
const { Sequelize } = require('sequelize');
const UserModel = require('./user');
const DriverModel = require('./driver');
const RideModel = require('./ride');
const RideRequestModel = require('./rideRequest');
const RideMessageModel = require('./rideMessage');
const RatingModel = require('./rating');
const ComplaintModel = require('./complaint');
const NotificationModel = require('./notification');

const UserDeviceModel = require('./userDevice');
const SavedPlaceModel = require('./savedPlace'); // NEW
const WalletModel = require('./Wallet');
const WalletTransactionModel = require('./WalletTransaction');
const VehicleChangeRequestModel = require('./vehicleChangeRequest');
const AnnouncementModel = require('./Announcement');

const sequelize = new Sequelize(
  process.env.DB_NAME || 'taksibu',
  process.env.DB_USER || 'root',
  process.env.DB_PASS || '',
  {
    host: process.env.DB_HOST || '127.0.0.1',
    port: process.env.DB_PORT || 3306,
    dialect: 'mysql',
    logging: false,
    define: {
      underscored: true,
      timestamps: true
    },
    // Performance: Connection Pooling
    pool: {
      max: 20,    // Increase max connections for higher load
      min: 5,     // Keep some connections open
      acquire: 30000,
      idle: 10000
    }
  }
);

const models = {
  User: UserModel(sequelize),
  Driver: DriverModel(sequelize),
  Ride: RideModel(sequelize),
  RideRequest: RideRequestModel(sequelize),
  RideMessage: RideMessageModel(sequelize),
  Rating: RatingModel(sequelize),
  Complaint: ComplaintModel(sequelize),
  Notification: NotificationModel(sequelize),

  UserDevice: UserDeviceModel(sequelize),
  SavedPlace: SavedPlaceModel(sequelize),
  Wallet: WalletModel(sequelize),
  WalletTransaction: WalletTransactionModel(sequelize),
  VehicleChangeRequest: VehicleChangeRequestModel(sequelize),
  Announcement: AnnouncementModel(sequelize)
};

// Associations
models.Driver.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });
models.User.hasOne(models.Driver, { foreignKey: 'user_id', as: 'driver' });
models.Driver.hasMany(models.VehicleChangeRequest, { foreignKey: 'driver_id', as: 'change_requests' });
models.VehicleChangeRequest.belongsTo(models.Driver, { foreignKey: 'driver_id', as: 'driver' });

models.Ride.belongsTo(models.User, { foreignKey: 'passenger_id', as: 'passenger' });
models.Ride.belongsTo(models.User, { foreignKey: 'driver_id', as: 'driver' });

models.RideRequest.belongsTo(models.Ride, { foreignKey: 'ride_id', as: 'ride' });
models.RideMessage.belongsTo(models.Ride, { foreignKey: 'ride_id', as: 'ride' });
models.RideMessage.belongsTo(models.User, { foreignKey: 'sender_id', as: 'sender' });

models.Rating.belongsTo(models.Ride, { foreignKey: 'ride_id', as: 'ride' });
models.Rating.belongsTo(models.User, { foreignKey: 'rater_id', as: 'rater' });
models.Rating.belongsTo(models.User, { foreignKey: 'rated_id', as: 'rated' });

models.Complaint.belongsTo(models.Ride, { foreignKey: 'ride_id', as: 'ride' });
models.Complaint.belongsTo(models.User, { foreignKey: 'complainer_id', as: 'complainer' });
models.Complaint.belongsTo(models.User, { foreignKey: 'accused_id', as: 'accused' });



// NEW: User <-> UserDevice
models.User.hasMany(models.UserDevice, { foreignKey: 'user_id', as: 'devices' });
models.UserDevice.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });

// NEW: User <-> SavedPlace
models.User.hasMany(models.SavedPlace, { foreignKey: 'user_id', as: 'saved_places' });
models.SavedPlace.belongsTo(models.User, { foreignKey: 'user_id', as: 'user' });

module.exports = {
  sequelize,
  ...models
};